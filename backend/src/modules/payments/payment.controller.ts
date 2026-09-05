import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { paystackService } from './paystack.service';
import { korapayService } from './korapay.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';
import { db } from '../../database';

export const paymentRouter = Router();

const initPaymentSchema = z.object({
  planId: z.string(),
});

// Driver initializes Paystack card payment checkout
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

    const isValid = await paystackService.verifyWebhookSignature(rawPayload, signature || '');
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
    console.error('Paystack webhook error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Dedicated Korapay Virtual Account (Fetch or Provision)
paymentRouter.get(
  '/virtual-account',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const user = await db.findUserById(req.user!.userId);
      if (!user) {
        res.status(404).json({ success: false, message: 'User not found.' });
        return;
      }

      const vba = await korapayService.generateDedicatedVirtualAccount(
        user.id,
        user.full_name,
        user.email,
        user.phone_number
      );

      res.status(200).json({ success: true, data: vba });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Korapay Webhook Handler (Incoming NIP Bank Transfers)
paymentRouter.post('/korapay/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = (req.headers['x-korapay-signature'] || '') as string;
    const rawPayload = JSON.stringify(req.body);

    const isValid = korapayService.verifyWebhookSignature(rawPayload, signature);
    if (!isValid) {
      res.status(400).send('Invalid Korapay signature');
      return;
    }

    await korapayService.handleVirtualAccountCreditWebhook(req.body);
    res.status(200).json({ status: 'success' });
  } catch (err: any) {
    console.error('Korapay webhook error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Development / Testing Utility: Simulate Instant NIP Bank Transfer
paymentRouter.post(
  '/korapay/simulate-bank-transfer',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { amountNgn } = req.body;
      const transferAmount = Number(amountNgn) || 5000;
      const updatedVba = await korapayService.simulateIncomingBankTransfer(req.user!.userId, transferAmount);
      res.json({ success: true, message: `Successfully simulated ₦${transferAmount.toLocaleString()} transfer.`, data: updatedVba });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);
