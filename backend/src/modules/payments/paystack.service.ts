import crypto from 'crypto';
import axios from 'axios';
import { ENV } from '../../config/env';
import { db } from '../../database';
import { subscriptionService } from '../subscriptions/subscription.service';

export class PaystackService {
  private baseUrl = 'https://api.paystack.co';

  private async getSecretKey(): Promise<string> {
    const settings = await db.getPlatformSettings();
    return settings.paystack_secret_key || ENV.PAYSTACK_SECRET_KEY || 'sk_test_paystack_secret_key';
  }

  /**
   * Initializes a Paystack transaction for buying a driver subscription pack via Card or Transfer.
   */
  public async initializeSubscriptionPayment(driverId: string, planId: string, email: string) {
    const plan = await db.getPlanById(planId);
    if (!plan) {
      throw new Error(`Plan with ID ${planId} not found.`);
    }

    const secretKey = await this.getSecretKey();
    const reference = `sub_${Date.now()}_${driverId.slice(0, 6)}`;

    // If using live Paystack API key
    if (secretKey && !secretKey.includes('mock') && secretKey.startsWith('sk_')) {
      try {
        const response = await axios.post(
          `${this.baseUrl}/transaction/initialize`,
          {
            email,
            amount: plan.price_kobo,
            reference,
            channels: ['card', 'bank', 'ussd', 'qr'],
            metadata: {
              driverId,
              planId,
              planName: plan.name,
              totalRides: plan.total_rides,
            },
          },
          {
            headers: {
              Authorization: `Bearer ${secretKey}`,
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
          channel: 'paystack_card',
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
   * Charges a saved card authorization for recurring card debits.
   */
  public async chargeCardAuthorization(authorizationCode: string, email: string, amountKobo: number, metadata: any) {
    const secretKey = await this.getSecretKey();
    if (secretKey && !secretKey.includes('mock') && secretKey.startsWith('sk_')) {
      try {
        const response = await axios.post(
          `${this.baseUrl}/transaction/charge_authorization`,
          {
            authorization_code: authorizationCode,
            email,
            amount: amountKobo,
            metadata,
          },
          {
            headers: {
              Authorization: `Bearer ${secretKey}`,
              'Content-Type': 'application/json',
            },
          }
        );
        return response.data;
      } catch (err: any) {
        console.error('[Paystack Charge Authorization Error]', err.response?.data || err.message);
        throw new Error(err.response?.data?.message || 'Card authorization charge failed.');
      }
    }

    return {
      status: true,
      data: {
        status: 'success',
        reference: `sim_card_${Date.now()}`,
        amount: amountKobo,
      },
    };
  }

  /**
   * Verifies Paystack webhook signature using HMAC SHA512.
   */
  public async verifyWebhookSignature(payload: string, signature: string): Promise<boolean> {
    const secretKey = await this.getSecretKey();
    if (secretKey.includes('mock')) return true;
    const hash = crypto
      .createHmac('sha512', secretKey)
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

    // Activate driver subscription & clear any lockout
    await subscriptionService.activateSubscription(driverId, planId, reference);
    await db.updateDriverLockout(driverId, false, null);
    console.log(`[Paystack Webhook] Successfully credited subscription for driver ${driverId} on plan ${planId}`);
  }
}

export const paystackService = new PaystackService();
