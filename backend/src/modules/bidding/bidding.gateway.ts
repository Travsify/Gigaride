import { Server as SocketIOServer, Socket } from 'socket.io';
import { authService } from '../auth/auth.service';
import { db } from '../../database';
import { geoSessionManager } from '../../common/redis';
import { subscriptionService } from '../subscriptions/subscription.service';
import { autoTopupService } from '../subscriptions/autoTopup.service';
import { calculateHaversineDistanceKm } from '../../common/geo';
import { oneSignalService } from '../notifications/onesignal.service';
import { twilioService } from '../notifications/twilio.service';
import { ENV } from '../../config/env';

interface AuthenticatedSocket extends Socket {
  user?: {
    userId: string;
    role: 'PASSENGER' | 'DRIVER' | 'ADMIN';
  };
}

let globalIo: SocketIOServer | null = null;

export function broadcastFleetAlert(target: 'ALL' | 'DRIVERS' | 'PASSENGERS', alertData: any) {
  if (!globalIo) return;
  if (target === 'DRIVERS') {
    globalIo.to('drivers_pool').emit('fleet:broadcast', alertData);
  } else if (target === 'PASSENGERS') {
    globalIo.to('passengers_pool').emit('fleet:broadcast', alertData);
  } else {
    globalIo.emit('fleet:broadcast', alertData);
  }
}

export function setupBiddingGateway(io: SocketIOServer) {
  globalIo = io;
  // Authentication middleware for Socket.io
  io.use((socket: AuthenticatedSocket, next) => {
    const token = socket.handshake.auth.token || socket.handshake.headers['authorization']?.replace('Bearer ', '');
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    try {
      const payload = authService.verifyToken(token);
      socket.user = {
        userId: payload.userId,
        role: payload.role,
      };
      next();
    } catch {
      next(new Error('Invalid authentication token'));
    }
  });

  io.on('connection', async (socket: AuthenticatedSocket) => {
    const user = socket.user!;
    console.log(`[Socket Connected] User ${user.userId} (${user.role}) joined on socket ${socket.id}`);

    // Join personal room for targeted alerts
    socket.join(`user:${user.userId}`);

    if (user.role === 'DRIVER') {
      const driverProfile = await db.getDriverProfile(user.userId);
      if (driverProfile?.kyc_status !== 'APPROVED') {
        socket.emit('kyc:required', {
          kycStatus: driverProfile?.kyc_status || 'PENDING',
          message: 'Drivers must be thoroughly verified and approved by Prembly before going live on the radar.',
        });
      } else {
        socket.join('drivers_pool');
        await db.updateDriverOnlineStatus(user.userId, true);
        const subStatus = await subscriptionService.getDriverSubscriptionStatus(user.userId);
        socket.emit('subscription:status', subStatus);
      }
    } else if (user.role === 'PASSENGER') {
      socket.join('passengers_pool');
    } else if (user.role === 'ADMIN') {
      socket.join('admin_room');
    }

    // --- Driver Location Updates, Entitlement Refresh & Breadcrumbs ---
    socket.on('driver:location', async (data: { latitude: number; longitude: number; isOnline?: boolean; activeRideId?: string; speedKmh?: number }) => {
      if (user.role !== 'DRIVER') return;

      const subStatus = await subscriptionService.getDriverSubscriptionStatus(user.userId);

      geoSessionManager.updateDriverLocation({
        driverId: user.userId,
        latitude: data.latitude,
        longitude: data.longitude,
        isOnline: data.isOnline ?? true,
        hasActiveSubscription: subStatus.canReceiveRides,
        remainingRides: subStatus.remainingRides,
        updatedAt: Date.now(),
      });

      // Record high-resolution breadcrumb if driver is currently on an active ride
      if (data.activeRideId) {
        db.recordRideBreadcrumb({
          ride_id: data.activeRideId,
          driver_id: user.userId,
          latitude: data.latitude,
          longitude: data.longitude,
          speed_kmh: data.speedKmh || 0,
        }).catch((err) => console.error('Failed to log GPS breadcrumb:', err));
      }
    });

    // --- Passenger creates / broadcasts ride request ---
    socket.on('ride:request', async (data: { rideId: string }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride) {
          socket.emit('error', { message: 'Ride request not found.' });
          return;
        }

        const settings = await db.getPlatformSettings();
        const radius = settings.search_radius_km || 7.0;

        // Find nearby eligible drivers (has active subscription and remaining rides)
        const nearbyDrivers = geoSessionManager.findNearbyEligibleDrivers(
          ride.pickup_lat,
          ride.pickup_lng,
          radius
        );

        console.log(`[Ride Dispatch] Broadcasting ride ${ride.id} to ${nearbyDrivers.length} eligible nearby drivers.`);

        // Notify each nearby driver individually with their pickup distance
        for (const candidate of nearbyDrivers) {
          io.to(`user:${candidate.driverId}`).emit('ride:new_request', {
            rideId: ride.id,
            pickupAddress: ride.pickup_address,
            dropoffAddress: ride.dropoff_address,
            pickupLat: ride.pickup_lat,
            pickupLng: ride.pickup_lng,
            dropoffLat: ride.dropoff_lat,
            dropoffLng: ride.dropoff_lng,
            distanceKm: ride.distance_km,
            riderOfferNgn: ride.rider_offer_ngn,
            suggestedFareNgn: ride.suggested_fare_ngn,
            driverPickupDistanceKm: candidate.distanceKm,
            createdAt: ride.created_at,
          });
        }

        // High-Priority Push Notification to nearby drivers (even if phone screen is locked or app minimized)
        const driverIds = nearbyDrivers.map(c => c.driverId);
        if (driverIds.length > 0) {
          oneSignalService.sendPush({
            userIds: driverIds,
            heading: '🚖 New Ride Request Nearby!',
            content: `Pickup: ${ride.pickup_address} (Offer: ₦${(ride.rider_offer_ngn || ride.suggested_fare_ngn || 0).toLocaleString()})`,
            data: { type: 'NEW_RIDE_REQUEST', rideId: ride.id }
          }).catch(e => console.error('[Driver Dispatch Push Error]', e.message));
        }
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- Driver submits a bid (Counter-offer or accept) ---
    socket.on('driver:submit_bid', async (data: { rideId: string; counterFareNgn: number; etaMinutes: number }) => {
      if (user.role !== 'DRIVER') return;

      try {
        // Gatekeeper check: Driver must have valid remaining rides
        const isEligible = await subscriptionService.isDriverEligibleForDispatch(user.userId);
        if (!isEligible) {
          socket.emit('subscription:exhausted', {
            message: 'You have exhausted your rides. Please purchase a subscription to bid on rides.',
          });
          return;
        }

        const ride = await db.getRideById(data.rideId);
        if (!ride || ride.status !== 'NEGOTIATING') {
          socket.emit('error', { message: 'This ride is no longer open for bidding.' });
          return;
        }

        // Save bid to database
        const bid = await db.createBid({
          id: `bid_${Date.now()}_${user.userId.slice(0, 5)}`,
          ride_id: data.rideId,
          driver_id: user.userId,
          counter_fare_ngn: data.counterFareNgn,
          eta_minutes: data.etaMinutes,
          status: 'OFFERED',
          created_at: new Date().toISOString(),
        });

        // Fetch driver profile & rating
        const driverProfile = await db.getDriverProfile(user.userId);
        const driverUser = await db.findUserById(user.userId);

        // Push real-time bid card to Passenger's screen
        io.to(`user:${ride.rider_id}`).emit('passenger:new_bid', {
          bidId: bid.id,
          rideId: ride.id,
          driverId: user.userId,
          driverName: driverUser?.full_name || 'Driver',
          driverPhone: driverUser?.phone_number,
          vehicleMake: driverProfile?.vehicle_make,
          vehicleModel: driverProfile?.vehicle_model,
          licensePlate: driverProfile?.license_plate,
          vehicleColor: driverProfile?.vehicle_color,
          counterFareNgn: bid.counter_fare_ngn,
          etaMinutes: bid.eta_minutes,
        });

        // 🚖 Push & In-App Notification to Passenger
        oneSignalService.sendBidAlertToPassenger(
          ride.rider_id,
          driverUser?.full_name || 'Verified Driver',
          bid.counter_fare_ngn,
          ride.id
        ).catch(() => {});

        db.createNotification({
          user_id: ride.rider_id,
          title: 'New Driver Offer Received',
          message: `${driverUser?.full_name || 'A verified driver'} offered ₦${bid.counter_fare_ngn.toLocaleString()} for your trip.`,
          type: 'BID',
          meta_data: { rideId: ride.id, bidId: bid.id, fareNgn: bid.counter_fare_ngn },
        }).catch(() => {});

        socket.emit('bid:sent', { success: true, bidId: bid.id });
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- Passenger selects and accepts a specific driver's bid ---
    socket.on('passenger:accept_bid', async (data: { rideId: string; driverId: string; agreedFareNgn: number }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride || ride.status !== 'NEGOTIATING') {
          socket.emit('error', { message: 'Ride is no longer available for confirmation.' });
          return;
        }

        // Lock the ride in DB
        await db.updateRideStatus(data.rideId, 'ACCEPTED', data.driverId, data.agreedFareNgn);
        await db.acceptBid(data.rideId, data.driverId);

        console.log(`[Ride Confirmed] Ride ${data.rideId} locked to Driver ${data.driverId} at ₦${data.agreedFareNgn}`);

        // Notify chosen driver
        io.to(`user:${data.driverId}`).emit('ride:assigned', {
          rideId: ride.id,
          agreedFareNgn: data.agreedFareNgn,
          pickupAddress: ride.pickup_address,
          dropoffAddress: ride.dropoff_address,
          pickupLat: ride.pickup_lat,
          pickupLng: ride.pickup_lng,
          dropoffLat: ride.dropoff_lat,
          dropoffLng: ride.dropoff_lng,
          riderId: ride.rider_id,
        });

        const riderUser = await db.findUserById(ride.rider_id);

        // 🎉 Push & In-App Notification to Driver
        oneSignalService.sendMatchAlertToDriver(
          data.driverId,
          riderUser?.full_name || 'Passenger',
          ride.pickup_address,
          ride.id
        ).catch(() => {});

        db.createNotification({
          user_id: data.driverId,
          title: 'Offer Accepted! Head to Pickup',
          message: `${riderUser?.full_name || 'Passenger'} accepted your offer of ₦${data.agreedFareNgn.toLocaleString()}. Pickup: ${ride.pickup_address}`,
          type: 'BID',
          meta_data: { rideId: ride.id, agreedFareNgn: data.agreedFareNgn },
        }).catch(() => {});

        // Notify passenger with confirmation
        socket.emit('ride:confirmed', {
          rideId: ride.id,
          driverId: data.driverId,
          agreedFareNgn: data.agreedFareNgn,
        });

        // Broadcast to general pool that this ride is closed
        io.emit('ride:closed', { rideId: ride.id });
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- Driver Updates Ride Lifecycle (ARRIVED -> IN_TRANSIT -> COMPLETED) ---
    socket.on('driver:update_status', async (data: { rideId: string; status: 'ARRIVED' | 'IN_TRANSIT' | 'COMPLETED' }) => {
      if (user.role !== 'DRIVER') return;

      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride) return;

        await db.updateRideStatus(data.rideId, data.status);

        // Notify passenger in real-time
        io.to(`user:${ride.rider_id}`).emit('ride:status_changed', {
          rideId: ride.id,
          status: data.status,
        });

        // 📲 Lifecycle Push & In-App Alerts to Passenger
        if (data.status === 'ARRIVED') {
          oneSignalService.sendPush({
            userIds: [ride.rider_id],
            heading: 'Driver Arrived at Pickup!',
            content: 'Your driver has arrived at your pickup spot. Please step outside.',
            data: { rideId: ride.id, status: 'ARRIVED' },
          }).catch(() => {});

          db.createNotification({
            user_id: ride.rider_id,
            title: 'Driver Arrived',
            message: 'Your driver has arrived and is waiting at your pickup point.',
            type: 'RIDE',
            meta_data: { rideId: ride.id },
          }).catch(() => {});
        } else if (data.status === 'IN_TRANSIT') {
          oneSignalService.sendPush({
            userIds: [ride.rider_id],
            heading: 'Trip Started 🚗',
            content: `You are en route to ${ride.dropoff_address}.`,
            data: { rideId: ride.id, status: 'IN_TRANSIT' },
          }).catch(() => {});
        } else if (data.status === 'COMPLETED') {
          const fare = ride.agreed_fare_ngn || ride.rider_offer_ngn;
          oneSignalService.sendPush({
            userIds: [ride.rider_id],
            heading: 'Trip Completed! Receipt Ready',
            content: `You arrived at ${ride.dropoff_address}. Total: ₦${fare.toLocaleString()}`,
            data: { rideId: ride.id, status: 'COMPLETED' },
          }).catch(() => {});

          db.createNotification({
            user_id: ride.rider_id,
            title: 'Trip Completed',
            message: `You arrived safely at ${ride.dropoff_address}. ₦${fare.toLocaleString()} settled.`,
            type: 'RIDE',
            meta_data: { rideId: ride.id, fareNgn: fare },
          }).catch(() => {});
        }

        // When ride is COMPLETED, deduct driver subscription credit atomically!
        if (data.status === 'COMPLETED') {
          const deduction = await subscriptionService.onRideCompleted(user.userId);

          // Notify driver of updated ride balance
          socket.emit('subscription:updated', {
            remainingRides: deduction.remainingRides,
            isExhausted: deduction.isExhausted,
            graceUsed: deduction.graceUsed,
          });

          // If exhausted, lock driver out of dispatch until they purchase more rides
          if (deduction.isExhausted) {
            socket.emit('subscription:exhausted', {
              message: 'You have completed all your subscribed rides! Please recharge to get more passengers.',
              remainingRides: deduction.remainingRides,
            });
          }

          // Trigger Auto Top-Up & 2-Grace Period Evaluation
          const topupResult = await autoTopupService.checkAndProcessDriverThreshold(user.userId);
          if (topupResult.renewed) {
            socket.emit('subscription:auto_renewed', { message: topupResult.message });
          } else if (topupResult.lockedOut) {
            socket.emit('subscription:lockout', { message: topupResult.message });
          } else if (topupResult.inGracePeriod) {
            socket.emit('subscription:grace_entered', { message: topupResult.message });
          }

          // Complete notification to passenger
          io.to(`user:${ride.rider_id}`).emit('ride:finished', {
            rideId: ride.id,
            finalFareNgn: ride.agreed_fare_ngn,
          });
        }
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- Emergency SOS Trigger (Passenger or Driver) ---
    socket.on('ride:sos_trigger', async (data: { rideId: string; latitude: number; longitude: number; notes?: string }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        const incident = await db.createSosIncident({
          id: `sos_${Date.now()}_${user.userId.slice(0, 5)}`,
          ride_id: data.rideId,
          driver_id: ride?.driver_id ?? undefined,
          rider_id: ride?.rider_id ?? user.userId,
          latitude: data.latitude,
          longitude: data.longitude,
          status: 'OPEN',
          notes: data.notes || 'Emergency SOS triggered from mobile app',
          created_at: new Date().toISOString(),
        });

        console.log(`🚨 [EMERGENCY SOS ALERT] Ride ${data.rideId} triggered by ${user.userId}!`);

        // Broadcast to Admin room in real-time
        io.to('admin_room').emit('admin:sos_alert', {
          incident,
          ride,
          triggeredByRole: user.role,
        });

        // 🚨 High Priority OneSignal Broadcast & SMS Dispatch
        const trackingUrl = `${ENV.API_BASE_URL}/track/${data.rideId}`;
        const triggerUser = await db.findUserById(user.userId);
        oneSignalService.sendSosAlert(
          triggerUser?.full_name || 'Rider',
          'GPS Live Tracking Active',
          trackingUrl
        ).catch(() => {});

        db.createNotification({
          user_id: user.userId,
          title: '🚨 SOS Alert Dispatched',
          message: 'Security response team and emergency dispatchers have been alerted with your live GPS location.',
          type: 'SOS',
          meta_data: { incidentId: incident.id, rideId: data.rideId },
        }).catch(() => {});

        socket.emit('sos:acknowledged', { success: true, incidentId: incident.id });
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- In-App Secure Calling (VoIP / Encrypted Signaling) ---
    // Passenger's personal phone number is NEVER exposed. Calls route via in-app WebSockets.
    socket.on('call:initiate', async (data: { rideId: string; receiverId: string }) => {
      try {
        const caller = await db.findUserById(user.userId);
        const callerName = user.role === 'DRIVER' ? (caller?.full_name || 'Driver') : (caller?.full_name || 'Passenger');

        console.log(`📞 [In-App Call] Initiated by ${user.role} (${user.userId}) to ${data.receiverId} for ride ${data.rideId}`);

        io.to(`user:${data.receiverId}`).emit('call:incoming', {
          rideId: data.rideId,
          callerId: user.userId,
          callerName,
          callerRole: user.role,
          timestamp: new Date().toISOString(),
        });
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    socket.on('call:answer', (data: { rideId: string; callerId: string }) => {
      console.log(`📞 [In-App Call Answered] User ${user.userId} answered call from ${data.callerId}`);
      io.to(`user:${data.callerId}`).emit('call:connected', {
        rideId: data.rideId,
        answeredBy: user.userId,
      });
      socket.emit('call:connected', {
        rideId: data.rideId,
        answeredBy: user.userId,
      });
    });

    socket.on('call:end', (data: { rideId: string; targetId: string; reason?: string }) => {
      console.log(`📞 [In-App Call Ended] by ${user.userId} for ride ${data.rideId}`);
      io.to(`user:${data.targetId}`).emit('call:ended', {
        rideId: data.rideId,
        endedBy: user.userId,
        reason: data.reason || 'Call ended',
      });
      socket.emit('call:ended', {
        rideId: data.rideId,
        endedBy: user.userId,
        reason: data.reason || 'Call ended',
      });
    });

    // --- In-App Gate & Ride Chat (Zero Number Exchange) ---
    socket.on('ride:chat_send', async (data: { rideId: string; receiverId: string; text: string }) => {
      try {
        const sender = await db.findUserById(user.userId);
        const senderName = user.role === 'DRIVER' ? (sender?.full_name || 'Driver') : (sender?.full_name || 'Passenger');
        const messagePayload = {
          id: `msg_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
          rideId: data.rideId,
          senderId: user.userId,
          senderName,
          senderRole: user.role,
          text: data.text,
          timestamp: new Date().toISOString(),
        };

        io.to(`user:${data.receiverId}`).emit('ride:chat_message', messagePayload);
        socket.emit('ride:chat_sent', messagePayload);
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- Disconnect & Cleanup ---
    socket.on('disconnect', async () => {
      if (user.role === 'DRIVER') {
        await db.updateDriverOnlineStatus(user.userId, false);
        const loc = geoSessionManager.getDriverLocation(user.userId);
        if (loc) {
          loc.isOnline = false;
          geoSessionManager.updateDriverLocation(loc);
        }
      }
      console.log(`[Socket Disconnected] User ${user.userId}`);
    });
  });
}
