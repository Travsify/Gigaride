import { Router, Response } from 'express';
import { z } from 'zod';
import { db } from '../../database';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';

export const adminRouter = Router();

// Protect all admin routes
adminRouter.use(requireAuth);
adminRouter.use(requireRole(['ADMIN']));

// Get pending KYC driver list
adminRouter.get('/drivers/pending-kyc', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const drivers = await db.getPendingKycDrivers();
    res.status(200).json({ success: true, data: drivers });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

const kycReviewSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED']),
});

// Approve or reject driver KYC
adminRouter.post('/drivers/:id/kyc-review', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { status } = kycReviewSchema.parse(req.body);
    const driverId = String(req.params.id);
    await db.updateDriverKyc(driverId, status);
    res.status(200).json({
      success: true,
      message: `Driver KYC has been updated to ${status}.`,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// Platform operational analytics
adminRouter.get('/analytics', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const stats = await db.getAnalytics();
    res.status(200).json({ success: true, data: stats });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});
