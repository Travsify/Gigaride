import { Server as SocketIOServer, Socket } from 'socket.io';
import { authService } from '../auth/auth.service';
import { db } from '../../database';
import { geoSessionManager } from '../../common/redis';
import { subscriptionService } from '../subscriptions/subscription.service';
import { autoTopupService } from '../subscriptions/autoTopup.service';
import { calculateHaversineDistanceKm } from '../../common/geo';

interface AuthenticatedSocket extends Socket {
  user?: {
    userId: string;
    role: 'PASSENGER' | 'DRIVER' | 'ADMIN';
  };
}

export function setupBiddingGateway(io: SocketIOServer) {
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
      socket.join('drivers_pool');
      // Mark driver online in DB and load subscription state
      await db.updateDriverOnlineStatus(user.userId, true);
      const subStatus = await subscriptionService.getDriverSubscriptionStatus(user.userId);
      socket.emit('subscription:status', subStatus);
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

        socket.emit('sos:acknowledged', { success: true, incidentId: incident.id });
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
