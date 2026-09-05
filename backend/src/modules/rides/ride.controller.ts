import { Router, Response } from 'express';
import { z } from 'zod';
import { rideService } from './ride.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';
import { db } from '../../database';

export const rideRouter = Router();

const estimateSchema = z.object({
  pickupLat: z.number(),
  pickupLng: z.number(),
  dropoffLat: z.number(),
  dropoffLng: z.number(),
});

const createRideSchema = z.object({
  pickupLat: z.number(),
  pickupLng: z.number(),
  pickupAddress: z.string(),
  dropoffLat: z.number(),
  dropoffLng: z.number(),
  dropoffAddress: z.string(),
  riderOfferNgn: z.number().positive(),
});

// Calculate fair suggested fare and minimum floor
rideRouter.post('/estimate', async (req, res: Response): Promise<void> => {
  try {
    const { pickupLat, pickupLng, dropoffLat, dropoffLng } = estimateSchema.parse(req.body);
    const estimate = await rideService.getFareEstimate(pickupLat, pickupLng, dropoffLat, dropoffLng);
    res.status(200).json({ success: true, data: estimate });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// Create a ride request
rideRouter.post(
  '/request',
  requireAuth,
  requireRole(['PASSENGER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const dto = createRideSchema.parse(req.body);
      const ride = await rideService.createRide(req.user!.userId, dto);
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
