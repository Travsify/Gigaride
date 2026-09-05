import { Router, Response } from 'express';
import { z } from 'zod';
import { rideService } from './ride.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';

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

// Driver history
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
