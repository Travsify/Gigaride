import { db } from '../../database';
import { subscriptionService } from './subscription.service';
import { resendService } from '../notifications/resend.service';
import { geoSessionManager } from '../../common/redis';

export class AutoTopupService {
  /**
   * Evaluates driver's remaining ride credits, executes automated top-up if threshold breached,
   * handles 2-grace rides window, and activates strict dispatch lockout upon default.
   */
  public async checkAndProcessDriverThreshold(driverId: string): Promise<{
    success: boolean;
    renewed?: boolean;
    inGracePeriod?: boolean;
    lockedOut?: boolean;
    message: string;
  }> {
    const settings = await db.getPlatformSettings();
    if (settings.auto_topup_enabled === false) {
      return { success: true, message: 'Auto top-up globally disabled by admin.' };
    }

    const profile = await db.getDriverProfile(driverId);
    if (!profile) return { success: false, message: 'Driver profile not found.' };

    const dossier = await db.getDriverDossier(driverId);
    const activeSub = dossier.subscriptions?.[0];
    if (!activeSub) return { success: false, message: 'No subscription history.' };

    const threshold = settings.auto_topup_threshold_rides || 2;
    const graceLimit = settings.grace_rides_limit || 2;
    const remainingRides = activeSub.remaining_rides;

    // Check if remaining rides is within top-up threshold
    if (remainingRides <= threshold) {
      const planId = profile.preferred_plan_id || settings.default_auto_topup_plan_id || 'plan_standard_50';
      const plan = await db.getPlanById(planId);
      if (!plan) return { success: false, message: 'Target subscription plan not found.' };

      const planPriceNgn = plan.price_kobo / 100;
      const vba = await db.getVirtualAccountByUserId(driverId);

      // Attempt debit from Korapay Dedicated Virtual Bank Account
      if (vba && vba.balance_ngn >= planPriceNgn) {
        try {
          await db.debitVirtualAccountBalance(vba.account_number, planPriceNgn);
          const reference = `auto_topup_${Date.now()}_${driverId.slice(0, 5)}`;

          // Record payment transaction
          await db.createTransaction({
            id: reference,
            reference,
            user_id: driverId,
            amount_kobo: plan.price_kobo,
            status: 'SUCCESS',
            payment_type: 'SUBSCRIPTION_PURCHASE',
            channel: 'korapay_virtual_account',
            meta_data: { autoTopup: true, planId: plan.id, planName: plan.name },
            created_at: new Date().toISOString(),
          });

          // Activate subscription (automatically recovers grace debt if remainingRides < 0)
          const newSub = await subscriptionService.activateSubscription(driverId, plan.id, reference);

          // Clear any lockout
          await db.updateDriverLockout(driverId, false, null);

          // Dispatched styled receipt via Resend
          const user = await db.findUserById(driverId);
          if (user) {
            await resendService.sendAutoTopupSuccess(user.email, user.full_name, plan.name, planPriceNgn, newSub.remaining_rides);
          }

          console.log(`[Auto Top-Up SUCCESS] Driver ${driverId} debited ₦${planPriceNgn} from virtual account. Remaining rides: ${newSub.remaining_rides}`);
          return { success: true, renewed: true, message: 'Subscription successfully auto-renewed from virtual account.' };
        } catch (e: any) {
          console.error('[Auto Top-Up Error]', e.message);
        }
      }

      // Auto top-up debit failed due to insufficient virtual account balance
      console.warn(`[Auto Top-Up FAILED] Driver ${driverId} has insufficient funds in virtual account (Balance: ₦${vba?.balance_ngn || 0} vs Required: ₦${planPriceNgn})`);

      // Evaluate 2 Emergency Grace Rides & Lockout
      if (remainingRides <= -graceLimit) {
        // Enforce strict dispatch lockout
        await db.updateDriverLockout(driverId, true, 'EXHAUSTED_GRACE_RIDES');
        await geoSessionManager.removeDriver(driverId);

        const user = await db.findUserById(driverId);
        if (user) {
          await resendService.sendDispatchLockoutAlert(user.email, user.full_name, vba ? {
            accountNumber: vba.account_number,
            bankName: vba.bank_name,
          } : undefined);
        }

        console.error(`[STRICT LOCKOUT] Driver ${driverId} exhausted all ${graceLimit} grace rides. EVICTED from dispatch radar.`);
        return {
          success: false,
          lockedOut: true,
          message: `Driver locked out from dispatch. Exhausted maximum of ${graceLimit} emergency grace rides.`,
        };
      }

      if (remainingRides <= 0) {
        // Driver is operating within grace rides (-1 or -2)
        const graceLeft = graceLimit + remainingRides;
        const user = await db.findUserById(driverId);
        if (user) {
          await resendService.sendGracePeriodWarning(user.email, user.full_name, graceLeft);
        }

        return {
          success: false,
          inGracePeriod: true,
          message: `Auto top-up failed. Driver is using emergency grace period (${graceLeft} grace rides remaining).`,
        };
      }
    }

    return { success: true, message: 'Ride count healthy above threshold.' };
  }
}

export const autoTopupService = new AutoTopupService();
