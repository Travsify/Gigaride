import crypto from 'crypto';
import axios from 'axios';
import { ENV } from '../../config/env';
import { db } from '../../database';
import { subscriptionService } from '../subscriptions/subscription.service';

export class PaystackService {
  private secretKey = ENV.PAYSTACK_SECRET_KEY;
  private baseUrl = 'https://api.paystack.co';

  /**
   * Initializes a Paystack transaction for buying a driver subscription pack.
   */
  public async initializeSubscriptionPayment(driverId: string, planId: string, email: string) {
    const plan = await db.getPlanById(planId);
    if (!plan) {
      throw new Error(`Plan with ID ${planId} not found.`);
    }

    const reference = `sub_${Date.now()}_${driverId.slice(0, 6)}`;

    // If using live Paystack API key
    if (this.secretKey && !this.secretKey.includes('mock')) {
      try {
        const response = await axios.post(
          `${this.baseUrl}/transaction/initialize`,
          {
            email,
            amount: plan.price_kobo,
            reference,
            metadata: {
              driverId,
              planId,
              planName: plan.name,
              totalRides: plan.total_rides,
            },
          },
          {
            headers: {
              Authorization: `Bearer ${this.secretKey}`,
              'Content-Type': 'application/json',
            },
          }
        );

        // Record pending transaction
        await db.createTransaction({
          id: reference,
          reference,
          user_id: driverId,
          amount_kobo: plan.price_kobo,
          status: 'PENDING',
          payment_type: 'SUBSCRIPTION_PURCHASE',
          channel: 'paystack',
          meta_data: { planId, planName: plan.name },
          created_at: new Date().toISOString(),
        });

        return {
          reference,
          authorizationUrl: response.data.data.authorization_url,
          accessCode: response.data.data.access_code,
          amountNgn: plan.price_kobo / 100,
        };
      } catch (err: any) {
        console.error('Paystack initialization error:', err.response?.data || err.message);
        throw new Error('Failed to initialize payment gateway.');
      }
    }

    // Direct sandbox/instant simulation mode when using test keys
    await db.createTransaction({
      id: reference,
      reference,
      user_id: driverId,
      amount_kobo: plan.price_kobo,
      status: 'PENDING',
      payment_type: 'SUBSCRIPTION_PURCHASE',
      channel: 'paystack_test',
      meta_data: { planId, planName: plan.name },
      created_at: new Date().toISOString(),
    });

    return {
      reference,
      authorizationUrl: `https://checkout.paystack.com/${reference}`,
      accessCode: reference,
      amountNgn: plan.price_kobo / 100,
      note: 'Payment gateway initialized. Pay via card, USSD, or direct bank transfer.',
    };
  }

  /**
   * Verifies Paystack webhook signature using HMAC SHA512.
   */
  public verifyWebhookSignature(payload: string, signature: string): boolean {
    if (this.secretKey.includes('mock')) return true;
    const hash = crypto
      .createHmac('sha512', this.secretKey)
      .update(payload)
      .digest('hex');
    return hash === signature;
  }

  /**
   * Processes Paystack `charge.success` event and activates subscription.
   */
  public async handleSuccessfulCharge(eventData: any) {
    const { reference, metadata, status } = eventData;
    if (status !== 'success') return;

    const driverId = metadata?.driverId;
    const planId = metadata?.planId;

    if (!driverId || !planId) {
      console.warn('Webhook charge.success received without driverId or planId metadata:', reference);
      return;
    }

    // Check if already processed
    const existingTx = await db.getTransactionByRef(reference);
    if (existingTx && existingTx.status === 'SUCCESS') {
      return; // Idempotent
    }

    // Update transaction
    await db.updateTransactionStatus(reference, 'SUCCESS');

    // Activate driver subscription
    await subscriptionService.activateSubscription(driverId, planId, reference);
    console.log(`[Payment Webhook] Successfully credited subscription for driver ${driverId} on plan ${planId}`);
  }
}

export const paystackService = new PaystackService();
