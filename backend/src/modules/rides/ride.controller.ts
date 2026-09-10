import { Router, Response } from 'express';
import { z } from 'zod';
import { rideService } from './ride.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';
import { db } from '../../database';
import { fincraService } from '../payments/fincra.service';
import { agoraService } from '../calls/agora.service';
import { dispatchRideToDrivers, notifyRideStatusChanged } from '../bidding/bidding.gateway';

export const rideRouter = Router();

const estimateSchema = z.object({
  pickupLat: z.number(),
  pickupLng: z.number(),
  dropoffLat: z.number(),
  dropoffLng: z.number(),
  distanceKm: z.number().optional().nullable(),
  durationMinutes: z.number().optional().nullable(),
});

const createRideSchema = z.object({
  pickupLat: z.number(),
  pickupLng: z.number(),
  pickupAddress: z.string(),
  dropoffLat: z.number(),
  dropoffLng: z.number(),
  dropoffAddress: z.string(),
  riderOfferNgn: z.number().positive(),
  riderName: z.string().optional().nullable(),
  riderPhone: z.string().optional().nullable(),
  riderType: z.enum(['SELF', 'FRIEND']).optional().nullable(),
  notes: z.string().optional().nullable(),
  isBusiness: z.boolean().optional().nullable(),
  hasWaitTime: z.boolean().optional().nullable(),
  requestedWaitMinutes: z.number().optional().nullable(),
  distanceKm: z.number().optional().nullable(),
  durationMinutes: z.number().optional().nullable(),
});

// Calculate fair suggested fare and minimum floor
rideRouter.post('/estimate', async (req, res: Response): Promise<void> => {
  try {
    const { pickupLat, pickupLng, dropoffLat, dropoffLng, distanceKm, durationMinutes } = estimateSchema.parse(req.body);
    const estimate = await rideService.getFareEstimate(
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
      distanceKm ?? undefined,
      durationMinutes ?? undefined
    );
    res.status(200).json({ success: true, data: estimate });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// Fetch active ride state for user (for app startup & socket reconnect sync)
rideRouter.get(
  '/active-state',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const activeRide = await db.findActiveRideForUser(req.user!.userId, req.user!.role);
      res.status(200).json({ success: true, data: activeRide });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Create a ride request
rideRouter.post(
  '/request',
  requireAuth,
  requireRole(['PASSENGER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const dto = createRideSchema.parse(req.body);
      const ride = await rideService.createRide(req.user!.userId, dto);
      
      // Auto-dispatch on server side immediately to all eligible drivers & pool
      dispatchRideToDrivers(ride.id).catch((err) => {
        console.error('[Auto-Dispatch Failed]', err);
      });

      res.status(201).json({ success: true, data: ride });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// Schedule Advance Airport or Interstate Ride
rideRouter.post(
  '/schedule',
  requireAuth,
  requireRole(['PASSENGER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const {
        pickupLat,
        pickupLng,
        pickupAddress,
        dropoffLat,
        dropoffLng,
        dropoffAddress,
        scheduledFor,
        riderOfferNgn,
        flightNumber,
        isAirport,
        isInterstate,
      } = req.body;

      if (!pickupLat || !pickupLng || !pickupAddress || !dropoffLat || !dropoffLng || !dropoffAddress || !scheduledFor || !riderOfferNgn) {
        res.status(400).json({ success: false, message: 'Missing required scheduled ride booking fields.' });
        return;
      }

      const ride = await rideService.scheduleRide(req.user!.userId, {
        pickupLat: Number(pickupLat),
        pickupLng: Number(pickupLng),
        pickupAddress: String(pickupAddress),
        dropoffLat: Number(dropoffLat),
        dropoffLng: Number(dropoffLng),
        dropoffAddress: String(dropoffAddress),
        scheduledFor: String(scheduledFor),
        riderOfferNgn: Number(riderOfferNgn),
        flightNumber: flightNumber ? String(flightNumber) : undefined,
        isAirport: Boolean(isAirport),
        isInterstate: Boolean(isInterstate),
      });

      res.status(201).json({
        success: true,
        message: 'Advance ride successfully scheduled. Drivers notified for dispatch queue.',
        data: ride,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// Get specific ride details
rideRouter.get(
  '/:id',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const rideId = String(req.params.id);
      const ride = await rideService.getRide(rideId);
      if (!ride) {
        res.status(404).json({ success: false, message: 'Ride not found' });
        return;
      }
      res.status(200).json({ success: true, data: ride });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Passenger history
rideRouter.get(
  '/history/passenger',
  requireAuth,
  requireRole(['PASSENGER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const history = await rideService.getRiderHistory(req.user!.userId);
      res.status(200).json({ success: true, data: history });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Driver ride & earnings history (for day/week/month/year analytics & date search)
rideRouter.get(
  '/history/driver',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const history = await rideService.getDriverHistory(req.user!.userId);
      res.status(200).json({ success: true, data: history });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);


// Passenger pays trip fare from Giga Wallet (Dedicated Virtual Account)
rideRouter.post(
  '/:id/pay-wallet',
  requireAuth,
  requireRole(['PASSENGER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const rideId = String(req.params.id);
      const ride = await db.getRideById(rideId);
      if (!ride) {
        res.status(404).json({ success: false, message: 'Ride not found' });
        return;
      }

      if (ride.rider_id !== req.user!.userId) {
        res.status(403).json({ success: false, message: 'Unauthorized.' });
        return;
      }

      if (!ride.driver_id) {
        res.status(400).json({ success: false, message: 'No driver assigned to this ride.' });
        return;
      }

      const fareNgn = ride.agreed_fare_ngn || ride.suggested_fare_ngn;
      const passengerVba = await db.getVirtualAccountByUserId(req.user!.userId);
      if (!passengerVba || passengerVba.balance_ngn < fareNgn) {
        res.status(400).json({
          success: false,
          message: `Insufficient wallet balance (Current: ₦${passengerVba?.balance_ngn || 0}, Required: ₦${fareNgn}). Please fund your dedicated virtual bank account.`,
        });
        return;
      }

      const driverVba = await db.getVirtualAccountByUserId(ride.driver_id);
      if (!driverVba) {
        res.status(400).json({ success: false, message: 'Driver virtual account not found.' });
        return;
      }

      // Deduct from passenger wallet & credit driver wallet
      await db.debitVirtualAccountBalance(passengerVba.account_number, fareNgn);
      await db.creditVirtualAccountBalance(driverVba.account_number, fareNgn);

      // Lock ride status to COMPLETED and notify both parties in real-time
      await db.updateRideStatus(rideId, 'COMPLETED');
      notifyRideStatusChanged(rideId, 'COMPLETED', ride.rider_id, ride.driver_id || undefined);

      res.status(200).json({
        success: true,
        message: `Successfully paid ₦${fareNgn.toLocaleString()} from Giga Wallet to driver.`,
        fareNgn,
        newPassengerBalance: (passengerVba.balance_ngn - fareNgn),
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Automatic Driver Virtual Bank Account for Cash/Transfer Payment Screen
rideRouter.get(
  '/:id/driver-bank-account',
  requireAuth,
  requireRole(['PASSENGER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const ride = await db.getRideById(String(req.params.id));
      if (!ride || !ride.driver_id) {
        res.status(404).json({ success: false, message: 'Driver or ride not found.' });
        return;
      }
      const driver = await db.findUserById(ride.driver_id);
      let vba = await db.getVirtualAccountByUserId(ride.driver_id);
      if (!vba || !vba.account_number) {
        vba = await fincraService.generateDedicatedVirtualAccount(
          driver!.id,
          driver!.full_name,
          driver!.email,
          driver!.phone_number
        );
      }
      const fareNgn = ride.agreed_fare_ngn || ride.suggested_fare_ngn || 0;

      res.status(200).json({
        success: true,
        data: {
          accountNumber: vba.account_number,
          bankName: vba.bank_name,
          accountName: vba.account_name,
          agreedFareNgn: fareNgn,
          driverName: driver?.full_name || 'Giga Driver Partner',
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// 📞 Get Agora RTC Voice Call Token for Active Ride
rideRouter.get(
  '/:id/call-token',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const rideId = String(req.params.id);
      const ride = await db.getRideById(rideId);
      if (!ride) {
        res.status(404).json({ success: false, message: 'Ride not found' });
        return;
      }

      // Ensure caller is participant
      if (ride.rider_id !== req.user!.userId && ride.driver_id !== req.user!.userId) {
        res.status(403).json({ success: false, message: 'Unauthorized for this ride channel.' });
        return;
      }

      const channelName = `ride_${rideId}`;
      const tokenData = await agoraService.generateRtcToken(channelName, 0);

      res.status(200).json({
        success: true,
        data: tokenData,
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// 💬 Get Persistent Chat Message History for Active/Past Ride
rideRouter.get(
  '/:id/messages',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const rideId = String(req.params.id);
      const ride = await db.getRideById(rideId);
      if (!ride) {
        res.status(404).json({ success: false, message: 'Ride not found' });
        return;
      }

      // Ensure requester is rider or driver or admin
      if (ride.rider_id !== req.user!.userId && ride.driver_id !== req.user!.userId && req.user!.role !== 'ADMIN') {
        res.status(403).json({ success: false, message: 'Unauthorized.' });
        return;
      }

      const messages = await db.getChatMessages(rideId);
      res.status(200).json({ success: true, data: messages });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// 🚗 Get Available Broadcasted Fares for Drivers
rideRouter.get(
  '/feed/available',
  requireAuth,
  requireRole(['DRIVER']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const available = await db.getAvailableBroadcastedRides();
      res.status(200).json({ success: true, data: available });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// 🔄 Driver updates ride lifecycle status (ARRIVED -> IN_TRANSIT -> COMPLETED)
rideRouter.patch(
  '/:id/status',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const rideId = String(req.params.id);
      const { status } = req.body;
      if (!status || !['ARRIVED', 'IN_TRANSIT', 'COMPLETED'].includes(status)) {
        res.status(400).json({ success: false, message: 'Invalid ride status.' });
        return;
      }

      const ride = await db.getRideById(rideId);
      if (!ride) {
        res.status(404).json({ success: false, message: 'Ride not found' });
        return;
      }

      await db.updateRideStatus(rideId, status);
      notifyRideStatusChanged(rideId, status, ride.rider_id, ride.driver_id || undefined);
      res.status(200).json({ success: true, data: { rideId, status } });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

