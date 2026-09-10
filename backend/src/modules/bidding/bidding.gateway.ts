import { Server as SocketIOServer, Socket } from 'socket.io';
import { authService } from '../auth/auth.service';
import { db } from '../../database';
import { geoSessionManager } from '../../common/redis';
import { subscriptionService } from '../subscriptions/subscription.service';
import { autoTopupService } from '../subscriptions/autoTopup.service';
import { calculateHaversineDistanceKm } from '../../common/geo';
import { oneSignalService } from '../notifications/onesignal.service';
import { twilioService } from '../notifications/twilio.service';
import { agoraService } from '../calls/agora.service';
import { ENV } from '../../config/env';

interface AuthenticatedSocket extends Socket {
  user?: {
    userId: string;
    role: 'PASSENGER' | 'DRIVER' | 'ADMIN';
  };
}

let globalIo: SocketIOServer | null = null;
const approachingAlertsSent = new Set<string>();

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

export function notifyRideStatusChanged(rideId: string, status: string, riderId?: string, driverId?: string) {
  if (!globalIo) return;
  const payload = { rideId, status };
  if (riderId) globalIo.to(`user:${riderId}`).emit('ride:status_changed', payload);
  if (driverId) globalIo.to(`user:${driverId}`).emit('ride:status_changed', payload);
  if (status === 'COMPLETED' || status === 'CANCELLED') {
    globalIo.emit('ride:closed', { rideId });
    if (status === 'CANCELLED') {
      if (riderId) globalIo.to(`user:${riderId}`).emit('ride:cancelled', { rideId, reason: 'Ride cancelled' });
      if (driverId) globalIo.to(`user:${driverId}`).emit('ride:cancelled', { rideId, reason: 'Ride cancelled' });
    }
  }
}

export async function dispatchRideToDrivers(rideId: string): Promise<boolean> {
  if (!globalIo) {
    console.warn(`[Ride Dispatch] Cannot dispatch ride ${rideId} - globalIo not initialized.`);
    return false;
  }

  try {
    const ride = await db.getRideById(rideId);
    if (!ride) {
      console.warn(`[Ride Dispatch] Ride ${rideId} not found for dispatch.`);
      return false;
    }

    const settings = await db.getPlatformSettings();
    const baseRadius = settings.search_radius_km || 7.0;

    // Tier 1: Search standard local radius (e.g. 7km)
    let nearbyDrivers = geoSessionManager.findNearbyEligibleDrivers(
      ride.pickup_lat,
      ride.pickup_lng,
      baseRadius
    );

    // Tier 2: If no drivers in immediate 7km, expand to 35km (metropolitan area)
    if (nearbyDrivers.length === 0) {
      console.log(`[Ride Dispatch] No drivers within ${baseRadius}km of (${ride.pickup_lat}, ${ride.pickup_lng}). Expanding to 35km metro radius...`);
      nearbyDrivers = geoSessionManager.findNearbyEligibleDrivers(
        ride.pickup_lat,
        ride.pickup_lng,
        35.0
      );
    }

    // Tier 3: If still 0, expand to 150km (regional / testing fallback)
    if (nearbyDrivers.length === 0) {
      console.log(`[Ride Dispatch] Expanding to 150km regional radius to ensure test devices / nearby city drivers are matched...`);
      nearbyDrivers = geoSessionManager.findNearbyEligibleDrivers(
        ride.pickup_lat,
        ride.pickup_lng,
        150.0
      );
    }

    // Tier 4: Fallback for testing / dev / zero-radius match
    if (nearbyDrivers.length === 0) {
      const allOnline = geoSessionManager.getAllOnlineDrivers();
      console.log(`[Ride Dispatch] Zero drivers within 150km. Fallback to all ${allOnline.length} online drivers.`);
      for (const d of allOnline) {
        nearbyDrivers.push({
          driverId: d.driverId,
          distanceKm: calculateHaversineDistanceKm(ride.pickup_lat, ride.pickup_lng, d.latitude, d.longitude),
          location: d,
        });
      }
    }

    const effectiveFare = ride.rider_offer_ngn || ride.suggested_fare_ngn || 3000;

    console.log(`[Ride Dispatch] Broadcasting ride ${ride.id} to ${nearbyDrivers.length} eligible drivers. Offer: ₦${effectiveFare}. Pickup: (${ride.pickup_lat}, ${ride.pickup_lng}) "${ride.pickup_address}"`);
    for (const candidate of nearbyDrivers) {
      console.log(` -> Driver matched: ${candidate.driverId}, Distance: ${candidate.distanceKm.toFixed(2)}km`);
    }

    const basePayload = {
      rideId: ride.id,
      pickupAddress: ride.pickup_address,
      dropoffAddress: ride.dropoff_address,
      pickupLat: ride.pickup_lat,
      pickupLng: ride.pickup_lng,
      dropoffLat: ride.dropoff_lat,
      dropoffLng: ride.dropoff_lng,
      distanceKm: ride.distance_km,
      riderOfferNgn: effectiveFare,
      rider_offer_ngn: effectiveFare,
      suggestedFareNgn: ride.suggested_fare_ngn || effectiveFare,
      suggested_fare_ngn: ride.suggested_fare_ngn || effectiveFare,
      fareNgn: effectiveFare,
      riderType: ride.rider_type || 'SELF',
      riderName: ride.rider_name || null,
      riderPhone: ride.rider_phone || null,
      notes: ride.notes || null,
      createdAt: ride.created_at,
    };

    // Notify each nearby driver individually with their pickup distance
    for (const candidate of nearbyDrivers) {
      globalIo.to(`user:${candidate.driverId}`).emit('ride:new_request', {
        ...basePayload,
        driverPickupDistanceKm: candidate.distanceKm,
      });
    }

    // Ambient broadcast to drivers_pool room so all active drivers receive it
    globalIo.to('drivers_pool').emit('ride:new_request', {
      ...basePayload,
      driverPickupDistanceKm: 1.5,
    });

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

    return true;
  } catch (err: any) {
    console.error(`[Ride Dispatch Error] Failed to dispatch ride ${rideId}:`, err);
    return false;
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

        // Pre-register online driver presence in geo session store if not yet set
        const existingLoc = geoSessionManager.getDriverLocation(user.userId);
        if (!existingLoc) {
          geoSessionManager.updateDriverLocation({
            driverId: user.userId,
            latitude: 6.5244,
            longitude: 3.3792,
            isOnline: true,
            hasActiveSubscription: subStatus.canReceiveRides,
            remainingRides: subStatus.remainingRides,
            updatedAt: Date.now(),
          });
        }
        console.log(`[Driver Socket] Driver ${user.userId} joined driver pool. Online=true, Sub=${subStatus.canReceiveRides}`);
      }
    } else if (user.role === 'PASSENGER') {
      socket.join('passengers_pool');
    } else if (user.role === 'ADMIN') {
      socket.join('admin_room');
    }

    // --- Driver Location Updates, Entitlement Refresh, Live Stream & Approaching Detection ---
    socket.on('driver:location', async (data: { latitude: number; longitude: number; isOnline?: boolean; activeRideId?: string; speedKmh?: number; heading?: number }) => {
      if (user.role !== 'DRIVER') return;

      const isOnline = data.isOnline ?? true;
      const subStatus = await subscriptionService.getDriverSubscriptionStatus(user.userId);

      geoSessionManager.updateDriverLocation({
        driverId: user.userId,
        latitude: data.latitude,
        longitude: data.longitude,
        isOnline: isOnline,
        hasActiveSubscription: subStatus.canReceiveRides,
        remainingRides: subStatus.remainingRides,
        updatedAt: Date.now(),
      });

      // 🚗 If driver has an active trip, stream high-res coordinates directly to passenger
      if (data.activeRideId) {
        db.recordRideBreadcrumb({
          ride_id: data.activeRideId,
          driver_id: user.userId,
          latitude: data.latitude,
          longitude: data.longitude,
          speed_kmh: data.speedKmh || 0,
        }).catch((err) => console.error('Failed to log GPS breadcrumb:', err));

        try {
          const ride = await db.getRideById(data.activeRideId);
          if (ride && ride.rider_id) {
            // Forward live coordinates & heading directly to passenger room
            io.to(`user:${ride.rider_id}`).emit('ride:driver_location', {
              rideId: data.activeRideId,
              driverId: user.userId,
              latitude: data.latitude,
              longitude: data.longitude,
              speedKmh: data.speedKmh || 0,
              heading: data.heading || 0,
              timestamp: Date.now(),
            });

            // Milestone: Driver Approaching (Within 500m / 0.5km of pickup)
            if (ride.status === 'ACCEPTED' && !approachingAlertsSent.has(ride.id)) {
              const distKm = calculateHaversineDistanceKm(
                data.latitude,
                data.longitude,
                ride.pickup_lat,
                ride.pickup_lng
              );
              if (distKm <= 0.55) {
                approachingAlertsSent.add(ride.id);
                const driverUser = await db.findUserById(user.userId);
                const driverName = driverUser?.full_name || 'Your driver';
                io.to(`user:${ride.rider_id}`).emit('ride:approaching', {
                  rideId: ride.id,
                  distanceKm: distKm,
                  etaMinutes: 2,
                });
                oneSignalService.sendDriverApproachingAlert(
                  ride.rider_id,
                  driverName,
                  null,
                  ride.id
                ).catch(() => {});
              }
            }
          }
        } catch (err) {
          console.error('Failed to process driver location update:', err);
        }
      }
    });

    // --- Passenger creates / broadcasts ride request ---
    socket.on('ride:request', async (data: { rideId: string }) => {
      try {
        const success = await dispatchRideToDrivers(data.rideId);
        if (!success) {
          socket.emit('error', { message: 'Failed to broadcast ride request.' });
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
          driverPhone: null, // NDPR Privacy Shield: Never expose driver cellular line to passenger
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

        const riderUser = await db.findUserById(ride.rider_id);
        const effectiveRiderName = ride.rider_name || riderUser?.full_name || 'Passenger';
        const effectiveRiderPhone = ride.rider_phone || riderUser?.phone_number || null;

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
          riderType: ride.rider_type || 'SELF',
          riderName: effectiveRiderName,
          riderPhone: effectiveRiderPhone,
          bookerName: riderUser?.full_name || 'Passenger',
          notes: ride.notes || null,
        });

        // 🎉 Push & In-App Notification to Driver
        oneSignalService.sendMatchAlertToDriver(
          data.driverId,
          effectiveRiderName,
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

        // 🚗 Push & In-App Notification to Passenger: Driver Assigned & En Route
        const driverUser = await db.findUserById(data.driverId);
        const driverProfile = await db.getDriverProfile(data.driverId);
        const driverName = driverUser?.full_name || 'Your Driver';
        const vehicleInfo = driverProfile
          ? `${driverProfile.vehicle_color || ''} ${driverProfile.vehicle_make} ${driverProfile.vehicle_model} (${driverProfile.license_plate})`.trim()
          : 'Verified Vehicle';

        oneSignalService.sendDriverAssignedToPassenger(
          ride.rider_id,
          driverName,
          vehicleInfo,
          4,
          ride.id
        ).catch(() => {});

        db.createNotification({
          user_id: ride.rider_id,
          title: 'Driver Confirmed & En Route',
          message: `${driverName} in ${vehicleInfo} is on the way to pick you up.`,
          type: 'RIDE',
          meta_data: { rideId: ride.id, driverId: data.driverId },
        }).catch(() => {});

        // Notify passenger with confirmation
        socket.emit('ride:confirmed', {
          rideId: ride.id,
          driverId: data.driverId,
          agreedFareNgn: data.agreedFareNgn,
          driverName: driverName,
          vehicleModel: driverProfile ? `${driverProfile.vehicle_make} ${driverProfile.vehicle_model}` : 'Toyota Corolla',
          licensePlate: driverProfile?.license_plate || '',
          driverPhone: null, // NDPR Privacy Shield: Never expose driver cellular line to passenger
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

        if (data.status === 'IN_TRANSIT') {
          io.to(`user:${ride.rider_id}`).emit('ride:commenced', {
            rideId: ride.id,
          });
          io.to(`user:${ride.rider_id}`).emit('ride:started', {
            rideId: ride.id,
          });
        }

        const driverUser = await db.findUserById(user.userId);
        const driverProfile = await db.getDriverProfile(user.userId);
        const driverName = driverUser?.full_name || 'Your Driver';
        const vehicleInfo = driverProfile
          ? `${driverProfile.vehicle_color || ''} ${driverProfile.vehicle_make} ${driverProfile.vehicle_model} (${driverProfile.license_plate})`.trim()
          : 'Verified Vehicle';

        // 📲 Lifecycle Push & In-App Alerts to Passenger
        if (data.status === 'ARRIVED') {
          oneSignalService.sendDriverArrivedAlert(
            ride.rider_id,
            driverName,
            vehicleInfo,
            ride.id
          ).catch(() => {});

          db.createNotification({
            user_id: ride.rider_id,
            title: 'Driver Has Arrived',
            message: `${driverName} has arrived outside in ${vehicleInfo}. Free wait time is 3 minutes.`,
            type: 'RIDE',
            meta_data: { rideId: ride.id, driverId: user.userId },
          }).catch(() => {});
        } else if (data.status === 'IN_TRANSIT') {
          oneSignalService.sendTripStartedAlert(
            ride.rider_id,
            ride.dropoff_address,
            ride.id
          ).catch(() => {});

          db.createNotification({
            user_id: ride.rider_id,
            title: 'Trip Commenced',
            message: `You are on the way to ${ride.dropoff_address}.`,
            type: 'RIDE',
            meta_data: { rideId: ride.id },
          }).catch(() => {});
        } else if (data.status === 'COMPLETED') {
          // If wait time was started but driver completed trip without explicit resume, close wait timer now
          if (ride.wait_start_time && !ride.wait_end_time) {
            const waitEndTime = new Date().toISOString();
            const elapsedSecs = Math.max(0, Math.floor((new Date(waitEndTime).getTime() - new Date(ride.wait_start_time).getTime()) / 1000));
            const settings = await db.getPlatformSettings();
            const graceMins = settings.wait_time_free_grace_mins !== undefined ? Number(settings.wait_time_free_grace_mins) : 5;
            const ratePerMin = settings.wait_time_rate_per_min_ngn !== undefined ? Number(settings.wait_time_rate_per_min_ngn) : 40;
            const commissionPct = settings.wait_time_commission_percent !== undefined ? Number(settings.wait_time_commission_percent) : 15;

            const totalWaitMins = Math.ceil(elapsedSecs / 60);
            const billableWaitMins = Math.max(0, totalWaitMins - graceMins);
            const waitFareNgn = billableWaitMins * ratePerMin;
            const waitCommNgn = Math.round(waitFareNgn * (commissionPct / 100));
            const driverPayoutNgn = waitFareNgn - waitCommNgn;

            await db.updateRideWaitTime(ride.id, {
              wait_end_time: waitEndTime,
              actual_wait_seconds: elapsedSecs,
              billable_wait_minutes: billableWaitMins,
              wait_fare_ngn: waitFareNgn,
              wait_commission_ngn: waitCommNgn,
              driver_wait_payout_ngn: driverPayoutNgn,
            });
            ride.wait_end_time = waitEndTime;
            ride.actual_wait_seconds = elapsedSecs;
            ride.billable_wait_minutes = billableWaitMins;
            ride.wait_fare_ngn = waitFareNgn;
            ride.wait_commission_ngn = waitCommNgn;
            ride.driver_wait_payout_ngn = driverPayoutNgn;
          }

          const baseFare = ride.agreed_fare_ngn || ride.rider_offer_ngn;
          const waitFare = ride.wait_fare_ngn || 0;
          const totalFare = baseFare + waitFare;
          const waitCommission = ride.wait_commission_ngn || 0;
          const driverWaitPayout = ride.driver_wait_payout_ngn || 0;

          oneSignalService.sendTripCompletedAlert(
            ride.rider_id,
            totalFare,
            ride.dropoff_address,
            ride.id
          ).catch(() => {});

          db.createNotification({
            user_id: ride.rider_id,
            title: 'Trip Completed',
            message: `You arrived safely at ${ride.dropoff_address}. ₦${totalFare.toLocaleString()} total${waitFare > 0 ? ` (includes ₦${waitFare.toLocaleString()} for ${ride.billable_wait_minutes} mins wait time)` : ''}.`,
            type: 'RIDE',
            meta_data: { rideId: ride.id, fareNgn: totalFare, waitFareNgn: waitFare },
          }).catch(() => {});

          // Trigger instant settlement modal on passenger's device with wait itemization
          io.to(`user:${ride.rider_id}`).emit('ride:finished', {
            rideId: ride.id,
            baseFareNgn: baseFare,
            waitFareNgn: waitFare,
            billableWaitMinutes: ride.billable_wait_minutes || 0,
            actualWaitSeconds: ride.actual_wait_seconds || 0,
            finalFareNgn: totalFare,
            waitCommissionNgn: waitCommission,
          });

          // Also notify driver with payout details
          socket.emit('ride:completed_breakdown', {
            rideId: ride.id,
            baseFareNgn: baseFare,
            driverWaitPayoutNgn: driverWaitPayout,
            totalDriverEarningsNgn: baseFare + driverWaitPayout,
            waitCommissionNgn: waitCommission,
            finalFareNgn: totalFare,
          });
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
        }
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // ⏱️ Stopover Wait Time Handlers
    socket.on('ride:start_wait', async (data: { rideId: string; stopAddress?: string }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride) return;

        const startTime = new Date().toISOString();
        const settings = await db.getPlatformSettings();
        const graceMins = settings.wait_time_free_grace_mins !== undefined ? Number(settings.wait_time_free_grace_mins) : 5;
        const ratePerMin = settings.wait_time_rate_per_min_ngn !== undefined ? Number(settings.wait_time_rate_per_min_ngn) : 40;

        await db.updateRideWaitTime(data.rideId, {
          wait_start_time: startTime,
          has_wait_time: true,
        });

        const payload = {
          rideId: ride.id,
          startTime,
          freeGraceMins: graceMins,
          ratePerMinuteNgn: ratePerMin,
          stopAddress: data.stopAddress || 'Stopover location',
        };

        // Notify both rider and driver
        io.to(`user:${ride.rider_id}`).emit('ride:wait_started', payload);
        socket.emit('ride:wait_started', payload);

        oneSignalService.sendWaitTimeStartedAlert(
          ride.rider_id,
          graceMins,
          ratePerMin,
          ride.id
        ).catch(() => {});
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    socket.on('ride:resume_trip', async (data: { rideId: string }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride || !ride.wait_start_time) return;

        const endTime = new Date().toISOString();
        const elapsedSecs = Math.max(0, Math.floor((new Date(endTime).getTime() - new Date(ride.wait_start_time).getTime()) / 1000));
        const settings = await db.getPlatformSettings();
        const graceMins = settings.wait_time_free_grace_mins !== undefined ? Number(settings.wait_time_free_grace_mins) : 5;
        const ratePerMin = settings.wait_time_rate_per_min_ngn !== undefined ? Number(settings.wait_time_rate_per_min_ngn) : 40;
        const commissionPct = settings.wait_time_commission_percent !== undefined ? Number(settings.wait_time_commission_percent) : 15;

        const totalWaitMins = Math.ceil(elapsedSecs / 60);
        const billableWaitMins = Math.max(0, totalWaitMins - graceMins);
        const waitFareNgn = billableWaitMins * ratePerMin;
        const waitCommNgn = Math.round(waitFareNgn * (commissionPct / 100));
        const driverPayoutNgn = waitFareNgn - waitCommNgn;

        await db.updateRideWaitTime(data.rideId, {
          wait_end_time: endTime,
          actual_wait_seconds: elapsedSecs,
          billable_wait_minutes: billableWaitMins,
          wait_fare_ngn: waitFareNgn,
          wait_commission_ngn: waitCommNgn,
          driver_wait_payout_ngn: driverPayoutNgn,
        });

        const payload = {
          rideId: ride.id,
          endTime,
          actualWaitSeconds: elapsedSecs,
          totalWaitMinutes: totalWaitMins,
          freeGraceMins: graceMins,
          billableWaitMinutes: billableWaitMins,
          waitFareNgn: waitFareNgn,
          waitCommissionNgn: waitCommNgn,
          driverWaitPayoutNgn: driverPayoutNgn,
        };

        io.to(`user:${ride.rider_id}`).emit('ride:wait_ended', payload);
        socket.emit('ride:wait_ended', payload);
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

    // --- In-App Secure Calling (VoIP / WebRTC Encrypted Audio) ---
    // Passenger's personal phone number is NEVER exposed. Audio routes peer-to-peer via WebRTC.
    socket.on('call:initiate', async (data: { rideId: string; receiverId: string }) => {
      try {
        const caller = await db.findUserById(user.userId);
        const callerName = user.role === 'DRIVER' ? (caller?.full_name || 'Driver') : (caller?.full_name || 'Passenger');
        const channelName = `ride_${data.rideId}`;
        let agoraData = { appId: '', token: '' };
        try {
          agoraData = await agoraService.generateRtcToken(channelName, 0);
        } catch (_) {}

        console.log(`📞 [In-App Call] Initiated by ${user.role} (${user.userId}) to ${data.receiverId} for ride ${data.rideId}`);

        io.to(`user:${data.receiverId}`).emit('call:incoming', {
          rideId: data.rideId,
          callerId: user.userId,
          callerName,
          callerRole: user.role,
          agoraAppId: agoraData.appId,
          agoraToken: agoraData.token,
          channelName,
          timestamp: new Date().toISOString(),
        });

        // Also notify caller
        socket.emit('call:token_ready', {
          rideId: data.rideId,
          agoraAppId: agoraData.appId,
          agoraToken: agoraData.token,
          channelName,
        });
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    socket.on('call:answer', async (data: { rideId: string; callerId: string }) => {
      try {
        const channelName = `ride_${data.rideId}`;
        let agoraData = { appId: '', token: '' };
        try {
          agoraData = await agoraService.generateRtcToken(channelName, 0);
        } catch (_) {}
        console.log(`📞 [In-App Call Answered] User ${user.userId} answered call from ${data.callerId}`);

        const connectPayload = {
          rideId: data.rideId,
          answeredBy: user.userId,
          agoraAppId: agoraData.appId,
          agoraToken: agoraData.token,
          channelName,
        };

        io.to(`user:${data.callerId}`).emit('call:connected', connectPayload);
        socket.emit('call:connected', connectPayload);
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // WebRTC Signaling: Offer SDP relay
    socket.on('call:signal_offer', (data: { rideId: string; targetId: string; sdp: any; type?: string }) => {
      console.log(`📡 [WebRTC Offer] From ${user.userId} to ${data.targetId} for ride ${data.rideId}`);
      io.to(`user:${data.targetId}`).emit('call:signal_offer', {
        rideId: data.rideId,
        senderId: user.userId,
        sdp: data.sdp,
        type: data.type || 'offer',
      });
    });

    // WebRTC Signaling: Answer SDP relay
    socket.on('call:signal_answer', (data: { rideId: string; targetId: string; sdp: any; type?: string }) => {
      console.log(`📡 [WebRTC Answer] From ${user.userId} to ${data.targetId} for ride ${data.rideId}`);
      io.to(`user:${data.targetId}`).emit('call:signal_answer', {
        rideId: data.rideId,
        senderId: user.userId,
        sdp: data.sdp,
        type: data.type || 'answer',
      });
    });

    // WebRTC Signaling: ICE Candidate relay
    socket.on('call:ice_candidate', (data: { rideId: string; targetId: string; candidate: any }) => {
      io.to(`user:${data.targetId}`).emit('call:ice_candidate', {
        rideId: data.rideId,
        senderId: user.userId,
        candidate: data.candidate,
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

    // --- In-App Gate & Ride Chat (Zero Number Exchange + Audio Walkie-Talkie Support) ---
    socket.on('ride:chat_send', async (data: { rideId: string; receiverId: string; text: string; isVoiceMemo?: boolean; durationSecs?: number }) => {
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
          isVoiceMemo: data.isVoiceMemo ?? false,
          durationSecs: data.durationSecs ?? null,
          timestamp: new Date().toISOString(),
        };

        io.to(`user:${data.receiverId}`).emit('ride:chat_message', messagePayload);
        socket.emit('ride:chat_sent', messagePayload);
        await db.saveChatMessage(messagePayload);
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- 💵 Cash / Bank Transfer Payment Settled Notification ---
    socket.on('ride:cash_payment_received', async (data: { rideId: string; amountNgn?: number }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride) return;

        const targetUserId = user.role === 'DRIVER' ? ride.rider_id : ride.driver_id;
        if (targetUserId) {
          io.to(`user:${targetUserId}`).emit('ride:cash_payment_received', {
            rideId: data.rideId,
            paidBy: user.userId,
            amountNgn: data.amountNgn || ride.agreed_fare_ngn || ride.suggested_fare_ngn,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- 🚫 Zero-Exploitation Ride Cancellation & Auto-Cascade ---
    socket.on('ride:cancel', async (data: { rideId: string; reason?: string }) => {
      try {
        const ride = await db.getRideById(data.rideId);
        if (!ride) return;

        await db.updateRideStatus(data.rideId, 'CANCELLED');
        const reason = data.reason || 'Ride cancelled by user';

        // Remove from all driver incoming request lists immediately
        io.emit('ride:closed', { rideId: ride.id });

        // Notify both passenger and driver
        io.to(`user:${ride.rider_id}`).emit('ride:cancelled', {
          rideId: ride.id,
          cancelledBy: user.role,
          reason,
        });

        if (ride.driver_id) {
          io.to(`user:${ride.driver_id}`).emit('ride:cancelled', {
            rideId: ride.id,
            cancelledBy: user.role,
            reason,
          });

          // Push alert to the opposite party
          if (user.role === 'PASSENGER') {
            oneSignalService.sendPush({
              userIds: [ride.driver_id],
              heading: 'Ride Cancelled by Passenger',
              content: `Reason: ${reason}`,
              data: { rideId: ride.id, type: 'RIDE_CANCELLED' },
            }).catch(() => {});
          } else {
            oneSignalService.sendPush({
              userIds: [ride.rider_id],
              heading: 'Driver Cancelled Ride',
              content: 'Your driver cancelled the trip. Tap to auto-assign the next nearest driver.',
              data: { rideId: ride.id, type: 'RIDE_CANCELLED' },
            }).catch(() => {});
          }
        }

        db.createNotification({
          user_id: user.role === 'PASSENGER' ? (ride.driver_id || '') : ride.rider_id,
          title: 'Ride Cancelled',
          message: `Trip to ${ride.dropoff_address} was cancelled. Reason: ${reason}`,
          type: 'RIDE',
          meta_data: { rideId: ride.id, reason },
        }).catch(() => {});
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- ⚠️ Real-Time In-Trip Complaint & Safety Mediation ---
    socket.on('ride:report_issue', async (data: { rideId: string; issueType: string; description: string }) => {
      try {
        const complaint = await db.recordRideComplaint(
          data.rideId,
          user.userId,
          user.role as 'PASSENGER' | 'DRIVER',
          data.issueType,
          data.description
        );

        socket.emit('ride:issue_logged', {
          success: true,
          complaintId: complaint.id,
          message: 'Issue reported to Giga Operations & Safety Desk. Resolution team alerted.',
        });

        // Broadcast to admin room for real-time security monitor
        io.to('admin_room').emit('safety:incident', {
          rideId: data.rideId,
          reporterId: user.userId,
          reporterRole: user.role,
          issueType: data.issueType,
          description: data.description,
          timestamp: new Date().toISOString(),
        });
      } catch (err: any) {
        socket.emit('error', { message: err.message });
      }
    });

    // --- 💵 Rollover Cash Change Directly to Passenger's Wallet ---
    socket.on('ride:settle_change_to_wallet', async (data: { rideId: string; tenderedNgn: number; agreedFareNgn: number }) => {
      try {
        const changeNgn = data.tenderedNgn - data.agreedFareNgn;
        if (changeNgn <= 0) {
          socket.emit('error', { message: 'Tendered amount must exceed fare to generate wallet change.' });
          return;
        }

        const ride = await db.getRideById(data.rideId);
        if (!ride || !ride.driver_id) {
          socket.emit('error', { message: 'Active ride or assigned driver not found.' });
          return;
        }

        const driver = await db.getDriverProfile(ride.driver_id);
        const driverUserId = driver ? driver.driver_id : ride.driver_id;

        // Double-entry settlement: Driver Debited, Passenger Credited, Zero Platform Loss
        const result = await db.settleCashChangeRollover(
          driverUserId,
          ride.rider_id,
          changeNgn,
          ride.id
        );

        // 1. Notify Passenger (Credited)
        io.to(`user:${ride.rider_id}`).emit('wallet:change_credited', {
          rideId: ride.id,
          changeNgn,
          newBalanceNgn: result.passengerBalance,
        });

        // 2. Notify Driver (Debited)
        io.to(`driver:${ride.driver_id}`).emit('wallet:change_debited', {
          rideId: ride.id,
          changeNgn,
          newBalanceNgn: result.driverBalance,
        });
        io.to(`user:${driverUserId}`).emit('wallet:change_debited', {
          rideId: ride.id,
          changeNgn,
          newBalanceNgn: result.driverBalance,
        });

        // 3. Push notifications to both parties
        oneSignalService.sendPush({
          userIds: [ride.rider_id],
          heading: '₦' + changeNgn.toLocaleString('en-NG') + ' Change Deposited!',
          content: 'Your driver rollover change was credited to your Wallet. New balance: ₦' + result.passengerBalance.toLocaleString('en-NG'),
          data: { type: 'WALLET_TOPUP', rideId: ride.id },
        }).catch(() => {});

        oneSignalService.sendPush({
          userIds: [driverUserId],
          heading: '₦' + changeNgn.toLocaleString('en-NG') + ' Change Deducted',
          content: '₦' + changeNgn.toLocaleString('en-NG') + ' debited for passenger change rollover. New driver balance: ₦' + result.driverBalance.toLocaleString('en-NG'),
          data: { type: 'WALLET_DEBIT', rideId: ride.id },
        }).catch(() => {});

        socket.emit('wallet:change_settled', {
          success: true,
          changeNgn,
          passengerBalance: result.passengerBalance,
          driverBalance: result.driverBalance,
        });
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
