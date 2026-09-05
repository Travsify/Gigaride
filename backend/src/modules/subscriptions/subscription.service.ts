import { v4 as uuidv4 } from 'uuid';
import { db, DriverSubscriptionRow, SubscriptionPlanRow } from '../../database';
import { geoSessionManager } from '../../common/redis';
import { ENV } from '../../config/env';

export class SubscriptionService {
  /**
   * Retrieves all currently active platform subscription plans.
   */
  public async getAvailablePlans(): Promise<SubscriptionPlanRow[]> {
    return db.getActivePlans();
  }

  /**
   * Retrieves driver subscription status, remaining rides, and entitlement state.
   */
  public async getDriverSubscriptionStatus(driverId: string): Promise<{
    hasActiveSubscription: boolean;
    canReceiveRides: boolean;
    remainingRides: number;
    planName?: string;
    expiresAt?: string;
    isGracePeriod: boolean;
    subscription?: DriverSubscriptionRow;
  }> {
    const sub = await db.getActiveDriverSubscription(driverId);
    if (!sub) {
      return {
        hasActiveSubscription: false,
        canReceiveRides: false,
        remainingRides: 0,
        isGracePeriod: false,
      };
    }

    const plan = await db.getPlanById(sub.plan_id);
    const isUnlimited = plan?.plan_type === 'UNLIMITED';
    const isGrace = sub.remaining_rides < 0 && sub.remaining_rides >= -ENV.MAX_GRACE_RIDES;
    const canReceiveRides = isUnlimited || sub.remaining_rides > -ENV.MAX_GRACE_RIDES;

    return {
      hasActiveSubscription: sub.status === 'ACTIVE',
      canReceiveRides,
      remainingRides: isUnlimited ? 999999 : sub.remaining_rides,
      planName: plan?.name,
      expiresAt: sub.expires_at,
      isGracePeriod: isGrace,
      subscription: sub,
    };
  }

  /**
   * Gatekeeper Check: Checks whether a driver is eligible to receive dispatch broadcast requests.
   * If driver has 0 rides (or has exceeded grace limit), they are strictly ineligible.
   */
  public async isDriverEligibleForDispatch(driverId: string): Promise<boolean> {
    const profile = await db.getDriverProfile(driverId);
    if (!profile || profile.account_status !== 'ACTIVE' || profile.kyc_status === 'REJECTED') {
      return false;
    }

    // Safety & Regulatory Gate: verify document expiration
    const now = new Date();
    if (profile.driver_license_expiry && new Date(profile.driver_license_expiry) < now) {
      return false;
    }
    if (profile.insurance_expiry && new Date(profile.insurance_expiry) < now) {
      return false;
    }
    if (profile.road_worthiness_expiry && new Date(profile.road_worthiness_expiry) < now) {
      return false;
    }

    const status = await this.getDriverSubscriptionStatus(driverId);
    return status.canReceiveRides;
  }

  /**
   * Deducts 1 ride upon trip completion.
   * If rides are exhausted, automatically updates driver's status and evicts them from the active dispatch pool.
   */
  public async onRideCompleted(driverId: string): Promise<{
    remainingRides: number;
    isExhausted: boolean;
    status: 'ACTIVE' | 'EXHAUSTED' | 'EXPIRED';
    graceUsed: boolean;
  }> {
    const result = await db.decrementDriverRide(driverId);

    const isExhausted = result.remainingRides <= -ENV.MAX_GRACE_RIDES;

    if (isExhausted) {
      // Driver has exhausted all rides! Update driver presence to remove them from active dispatch radar.
      const loc = geoSessionManager.getDriverLocation(driverId);
      if (loc) {
        loc.hasActiveSubscription = false;
        loc.remainingRides = result.remainingRides;
        geoSessionManager.updateDriverLocation(loc);
      }
      console.log(`[Subscription Alert] Driver ${driverId} has exhausted all subscription rides! Deactivated from dispatch.`);
    } else {
      // Update remaining rides in memory geo store
      const loc = geoSessionManager.getDriverLocation(driverId);
      if (loc) {
        loc.remainingRides = result.remainingRides;
        geoSessionManager.updateDriverLocation(loc);
      }
    }

    return {
      remainingRides: result.remainingRides,
      isExhausted,
      status: result.status,
      graceUsed: result.graceUsed,
    };
  }

  /**
   * Activates a purchased subscription plan for a driver.
   * Automatically recovers any negative grace balance used during emergency grace trips.
   */
  public async activateSubscription(driverId: string, planId: string, paymentReference?: string): Promise<DriverSubscriptionRow> {
    const plan = await db.getPlanById(planId);
    if (!plan) {
      throw new Error(`Subscription plan ${planId} not found.`);
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + plan.duration_days * 24 * 60 * 60 * 1000);

    // Negative grace balance debt carryover recovery
    const existingSub = await db.getActiveDriverSubscription(driverId);
    let finalRemainingRides = plan.total_rides !== null ? plan.total_rides : 999999;

    if (existingSub && existingSub.remaining_rides < 0 && plan.total_rides !== null) {
      const graceDebt = Math.abs(existingSub.remaining_rides);
      finalRemainingRides = Math.max(0, finalRemainingRides - graceDebt);
      console.log(`[Grace Debt Recovery] Deducted ${graceDebt} grace rides from Driver ${driverId}. Allocated net: ${finalRemainingRides}`);
    }

    const newSub: DriverSubscriptionRow = {
      id: uuidv4(),
      driver_id: driverId,
      plan_id: plan.id,
      status: 'ACTIVE',
      remaining_rides: finalRemainingRides,
      starts_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      created_at: now.toISOString(),
    };

    const saved = await db.createDriverSubscription(newSub);

    // Re-enable driver on live geo dispatch
    const loc = geoSessionManager.getDriverLocation(driverId);
    if (loc) {
      loc.hasActiveSubscription = true;
      loc.remainingRides = saved.remaining_rides;
      geoSessionManager.updateDriverLocation(loc);
    }

    console.log(`[Subscription] Driver ${driverId} successfully activated plan: ${plan.name} (${saved.remaining_rides} rides)`);
    return saved;
  }
}

export const subscriptionService = new SubscriptionService();
