import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { paystackService } from './paystack.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';

export const paymentRouter = Router();

const initPaymentSchema = z.object({
  planId: z.string(),
});

// Driver initializes payment checkout
paymentRouter.post(
  '/initialize',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { planId } = initPaymentSchema.parse(req.body);
      const result = await paystackService.initializeSubscriptionPayment(
        req.user!.userId,
        planId,
        req.user!.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// Paystack Webhook Handler
paymentRouter.post('/paystack/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = req.headers['x-paystack-signature'] as string;
    const rawPayload = JSON.stringify(req.body);

    const isValid = paystackService.verifyWebhookSignature(rawPayload, signature || '');
    if (!isValid) {
      res.status(400).send('Invalid signature');
      return;
    }

    const event = req.body;
    if (event.event === 'charge.success') {
      await paystackService.handleSuccessfulCharge(event.data);
    }

    res.status(200).json({ status: 'success' });
  } catch (err: any) {
    console.error('Webhook processing error:', err);
    res.status(500).json({ error: err.message });
  }
});
