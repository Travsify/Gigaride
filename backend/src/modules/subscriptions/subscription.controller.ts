import { Router, Response } from 'express';
import { z } from 'zod';
import { subscriptionService } from './subscription.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';

export const subscriptionRouter = Router();

// Public: Get all available platform subscription plans
subscriptionRouter.get('/plans', async (_req, res: Response): Promise<void> => {
  try {
    const plans = await subscriptionService.getAvailablePlans();
    res.status(200).json({ success: true, data: plans });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Driver: Get current subscription status, remaining rides & grace state
subscriptionRouter.get(
  '/status',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const status = await subscriptionService.getDriverSubscriptionStatus(req.user!.userId);
      res.status(200).json({ success: true, data: status });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

const purchaseSchema = z.object({
  planId: z.string(),
  paymentReference: z.string().optional(),
});

// Driver: Activate / Purchase a subscription plan
subscriptionRouter.post(
  '/purchase',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { planId, paymentReference } = purchaseSchema.parse(req.body);
      const subscription = await subscriptionService.activateSubscription(
        req.user!.userId,
        planId,
        paymentReference
      );
      res.status(200).json({
        success: true,
        message: 'Subscription plan activated successfully.',
        data: subscription,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);
