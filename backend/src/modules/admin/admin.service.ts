import { db, PlatformSettingsRow, SubscriptionPlanRow, AdminAuditLogRow, DisputeRow } from '../../database';
import { geoSessionManager } from '../../common/redis';

export class AdminService {
  public async getAnalytics() {
    return db.getAnalytics();
  }

  public async getDrivers(filter?: 'ALL' | 'PENDING_KYC' | 'APPROVED' | 'REJECTED' | 'EXHAUSTED' | 'SUSPENDED') {
    return db.getAllDrivers(filter);
  }

  public async getDriverDossier(driverId: string) {
    const dossier = await db.getDriverDossier(driverId);
    if (!dossier) throw new Error('Driver not found.');
    return dossier;
  }

  public async reviewKyc(
    adminUser: { id: string; email: string },
    driverId: string,
    status: 'APPROVED' | 'REJECTED',
    rejectionReason?: string,
    ipAddress?: string
  ) {
    await db.updateDriverKyc(driverId, status, rejectionReason);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: status === 'APPROVED' ? 'DRIVER_KYC_APPROVED' : 'DRIVER_KYC_REJECTED',
      resource_type: 'DRIVER_PROFILE',
      resource_id: driverId,
      details: { status, rejectionReason },
      ip_address: ipAddress,
    });

    return { driverId, status, rejectionReason };
  }

  public async updateDriverDocuments(
    adminUser: { id: string; email: string },
    driverId: string,
    docs: {
      driver_license_expiry?: string;
      insurance_expiry?: string;
      road_worthiness_expiry?: string;
      lasdri_card_number?: string;
      lasdri_expiry?: string;
    },
    ipAddress?: string
  ) {
    const updated = await db.updateDriverDocuments(driverId, docs);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'DRIVER_DOCUMENTS_UPDATED',
      resource_type: 'DRIVER_PROFILE',
      resource_id: driverId,
      details: docs,
      ip_address: ipAddress,
    });

    return updated;
  }

  public async getExpiringComplianceDrivers(daysAhead: number = 30) {
    return db.getExpiringComplianceDrivers(daysAhead);
  }

  public async setDriverAccountStatus(
    adminUser: { id: string; email: string },
    driverId: string,
    accountStatus: 'ACTIVE' | 'SUSPENDED' | 'BANNED',
    ipAddress?: string
  ) {
    await db.setDriverAccountStatus(driverId, accountStatus);
    if (accountStatus !== 'ACTIVE') {
      geoSessionManager.removeDriver(driverId);
    }

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: `DRIVER_ACCOUNT_${accountStatus}`,
      resource_type: 'DRIVER_PROFILE',
      resource_id: driverId,
      details: { accountStatus },
      ip_address: ipAddress,
    });

    return { driverId, accountStatus };
  }

  public async unlockDriver(
    adminUser: { id: string; email: string },
    driverId: string,
    ipAddress?: string
  ) {
    await db.updateDriverLockout(driverId, false);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'DRIVER_LOCKOUT_CLEARED',
      resource_type: 'DRIVER_PROFILE',
      resource_id: driverId,
      details: { manual_override: true },
      ip_address: ipAddress,
    });
    return { driverId, is_locked_out: false };
  }

  public async manualCreditRides(
    adminUser: { id: string; email: string },
    driverId: string,
    ridesToAdd: number,
    reason: string,
    ipAddress?: string
  ) {
    if (ridesToAdd <= 0) throw new Error('Rides to credit must be greater than 0.');
    if (!reason || reason.trim().length < 3) throw new Error('A detailed operational reason is required for audit logs.');

    const updatedSub = await db.addManualRideCredit(adminUser.id, driverId, ridesToAdd, reason);

    // Refresh live driver presence in Redis / GeoStore
    const loc = geoSessionManager.getDriverLocation(driverId);
    if (loc) {
      loc.hasActiveSubscription = true;
      loc.remainingRides = updatedSub.remaining_rides;
      geoSessionManager.updateDriverLocation(loc);
    }

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'MANUAL_RIDE_CREDIT_GRANTED',
      resource_type: 'DRIVER_SUBSCRIPTION',
      resource_id: driverId,
      details: { ridesToAdd, reason, newBalance: updatedSub.remaining_rides },
      ip_address: ipAddress,
    });

    return updatedSub;
  }

  public async getCreditAudits(driverId?: string) {
    return db.getCreditAudits(driverId);
  }

  // --- Dynamic Subscription Plan CRUD ---
  public async getSubscriptionPlans() {
    return db.getAllPlans();
  }

  public async createSubscriptionPlan(
    adminUser: { id: string; email: string },
    plan: SubscriptionPlanRow,
    ipAddress?: string
  ) {
    const created = await db.createSubscriptionPlan(plan);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'SUBSCRIPTION_PLAN_CREATED',
      resource_type: 'SUBSCRIPTION_PLAN',
      resource_id: plan.id,
      details: plan,
      ip_address: ipAddress,
    });

    return created;
  }

  public async updateSubscriptionPlan(
    adminUser: { id: string; email: string },
    id: string,
    updates: Partial<SubscriptionPlanRow>,
    ipAddress?: string
  ) {
    const updated = await db.updateSubscriptionPlan(id, updates);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'SUBSCRIPTION_PLAN_UPDATED',
      resource_type: 'SUBSCRIPTION_PLAN',
      resource_id: id,
      details: updates,
      ip_address: ipAddress,
    });

    return updated;
  }

  public async deleteSubscriptionPlan(
    adminUser: { id: string; email: string },
    id: string,
    ipAddress?: string
  ) {
    const deleted = await db.deleteSubscriptionPlan(id);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'SUBSCRIPTION_PLAN_DELETED',
      resource_type: 'SUBSCRIPTION_PLAN',
      resource_id: id,
      details: { id },
      ip_address: ipAddress,
    });

    return deleted;
  }

  // --- Immutable Admin Audit Logs ---
  public async getAuditLogs(limit?: number, action?: string) {
    return db.getAdminAuditLogs(limit, action);
  }

  // --- Customer Support & Driver Disputes ---
  public async createDispute(data: {
    ride_id: string;
    reporter_id: string;
    reporter_role: 'PASSENGER' | 'DRIVER';
    dispute_type: string;
    description: string;
  }) {
    return db.createDispute(data);
  }

  public async getDisputes(status?: string) {
    return db.getDisputes(status);
  }

  public async resolveDispute(
    adminUser: { id: string; email: string },
    id: string,
    notes: string,
    driverStrikeApplied: boolean = false,
    compensationRides: number = 0,
    ipAddress?: string
  ) {
    const resolved = await db.resolveDispute(id, notes, driverStrikeApplied, compensationRides);

    // If compensation rides awarded, credit them to the reporter if driver
    if (compensationRides > 0 && resolved.reporter_role === 'DRIVER') {
      await db.addManualRideCredit(
        adminUser.id,
        resolved.reporter_id,
        compensationRides,
        `Dispute Compensation: ${notes}`
      );
    }

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'DISPUTE_RESOLVED',
      resource_type: 'DISPUTE',
      resource_id: id,
      details: { notes, driverStrikeApplied, compensationRides },
      ip_address: ipAddress,
    });

    return resolved;
  }

  // --- High-Resolution GPS Breadcrumbs ---
  public async getRideBreadcrumbs(rideId: string) {
    return db.getRideBreadcrumbs(rideId);
  }

  // --- LASG Ministry of Transportation ₦50 Levy Audit CSV Export ---
  public async exportLasgMotReportCsv(): Promise<string> {
    const rides = await db.getCompletedRidesForMotExport();
    const headers = [
      'Trip ID',
      'Completed Timestamp',
      'Driver Name',
      'Driver Phone',
      'Driver NIN',
      'Vehicle Plate',
      'Passenger Name',
      'Pickup Address',
      'Dropoff Address',
      'Distance (KM)',
      'Agreed Fare (NGN)',
      'LASG MOT Levy (NGN)',
    ];

    const escapeCsv = (str: any) => {
      if (str === null || str === undefined) return '""';
      const text = String(str).replace(/"/g, '""');
      return `"${text}"`;
    };

    const rows = rides.map((r) => [
      escapeCsv(r.ride_id),
      escapeCsv(r.completed_at),
      escapeCsv(r.driver_name),
      escapeCsv(r.driver_phone),
      escapeCsv(r.driver_nin),
      escapeCsv(r.license_plate),
      escapeCsv(r.passenger_name),
      escapeCsv(r.pickup_address),
      escapeCsv(r.dropoff_address),
      escapeCsv(r.distance_km),
      escapeCsv(r.agreed_fare_ngn),
      escapeCsv(r.lagos_mot_levy_ngn),
    ]);

    return [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
  }

  public async getActiveRides() {
    return db.getActiveRides();
  }

  public async getLiveFleet() {
    const allDrivers = await db.getAllDrivers('ALL');
    return allDrivers
      .filter((d) => d.is_online)
      .map((d) => {
        const geo = geoSessionManager.getDriverLocation(d.driver_id);
        return {
          driverId: d.driver_id,
          name: d.user?.full_name,
          phone: d.user?.phone_number,
          vehicle: `${d.vehicle_color} ${d.vehicle_make} ${d.vehicle_model}`,
          plate: d.license_plate,
          remainingRides: d.subscription?.remaining_rides ?? 0,
          latitude: geo?.latitude ?? 6.518,
          longitude: geo?.longitude ?? 3.379,
          lastSeen: geo?.updatedAt ? new Date(geo.updatedAt).toISOString() : new Date().toISOString(),
        };
      });
  }

  public async getSosIncidents(status?: 'OPEN' | 'IN_REVIEW' | 'RESOLVED') {
    return db.getSosIncidents(status);
  }

  public async resolveSosIncident(
    adminUser: { id: string; email: string },
    id: string,
    notes: string,
    ipAddress?: string
  ) {
    await db.resolveSosIncident(id, notes);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'SOS_INCIDENT_RESOLVED',
      resource_type: 'SOS_INCIDENT',
      resource_id: id,
      details: { notes },
      ip_address: ipAddress,
    });

    return { id, status: 'RESOLVED', notes };
  }

  public async getPlatformSettings(): Promise<PlatformSettingsRow> {
    return db.getPlatformSettings();
  }

  public async updatePlatformSettings(
    adminUser: { id: string; email: string },
    settings: Partial<PlatformSettingsRow>,
    ipAddress?: string
  ): Promise<PlatformSettingsRow> {
    const updated = await db.updatePlatformSettings(settings);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'PLATFORM_SETTINGS_UPDATED',
      resource_type: 'PLATFORM_SETTINGS',
      details: settings,
      ip_address: ipAddress,
    });

    return updated;
  }

  public async getIntegrationSettings() {
    const s = await db.getPlatformSettings();
    const maskKey = (key?: string) => {
      if (!key) return '';
      if (key.length <= 6) return '******';
      return `${key.slice(0, 4)}****${key.slice(-3)}`;
    };

    return {
      prembly_api_key: maskKey(s.prembly_api_key),
      prembly_app_id: s.prembly_app_id || '',
      prembly_auto_approve: s.prembly_auto_approve !== false,
      paystack_secret_key: maskKey(s.paystack_secret_key),
      paystack_public_key: s.paystack_public_key || '',
      paystack_webhook_secret: maskKey(s.paystack_webhook_secret),
      korapay_secret_key: maskKey(s.korapay_secret_key),
      korapay_public_key: s.korapay_public_key || '',
      korapay_encryption_key: maskKey(s.korapay_encryption_key),
      korapay_merchant_id: s.korapay_merchant_id || '',
      resend_api_key: maskKey(s.resend_api_key),
      resend_from_email: s.resend_from_email || 'notifications@gigaride.ng',
      twilio_account_sid: s.twilio_account_sid || '',
      twilio_auth_token: maskKey(s.twilio_auth_token),
      twilio_phone_number: s.twilio_phone_number || '',
      twilio_verify_sid: s.twilio_verify_sid || '',
      auto_topup_enabled: s.auto_topup_enabled !== false,
      auto_topup_threshold_rides: s.auto_topup_threshold_rides || 2,
      default_auto_topup_plan_id: s.default_auto_topup_plan_id || 'plan_standard_50',
      grace_rides_limit: s.grace_rides_limit || 2,
      subscription_rollover_enabled: s.subscription_rollover_enabled !== false,
    };
  }

  public async updateIntegrationSettings(
    adminUser: { id: string; email: string },
    payload: any,
    ipAddress?: string
  ) {
    const current = await db.getPlatformSettings();
    const cleanSetting = (newVal: any, oldVal?: string) => {
      if (newVal === undefined) return oldVal;
      if (typeof newVal === 'string' && newVal.includes('****')) return oldVal;
      return newVal;
    };

    const updateData: Partial<PlatformSettingsRow> = {
      prembly_api_key: cleanSetting(payload.prembly_api_key, current.prembly_api_key),
      prembly_app_id: cleanSetting(payload.prembly_app_id, current.prembly_app_id),
      prembly_auto_approve: payload.prembly_auto_approve !== undefined ? Boolean(payload.prembly_auto_approve) : current.prembly_auto_approve,
      paystack_secret_key: cleanSetting(payload.paystack_secret_key, current.paystack_secret_key),
      paystack_public_key: cleanSetting(payload.paystack_public_key, current.paystack_public_key),
      paystack_webhook_secret: cleanSetting(payload.paystack_webhook_secret, current.paystack_webhook_secret),
      korapay_secret_key: cleanSetting(payload.korapay_secret_key, current.korapay_secret_key),
      korapay_public_key: cleanSetting(payload.korapay_public_key, current.korapay_public_key),
      korapay_encryption_key: cleanSetting(payload.korapay_encryption_key, current.korapay_encryption_key),
      korapay_merchant_id: cleanSetting(payload.korapay_merchant_id, current.korapay_merchant_id),
      resend_api_key: cleanSetting(payload.resend_api_key, current.resend_api_key),
      resend_from_email: cleanSetting(payload.resend_from_email, current.resend_from_email),
      twilio_account_sid: cleanSetting(payload.twilio_account_sid, current.twilio_account_sid),
      twilio_auth_token: cleanSetting(payload.twilio_auth_token, current.twilio_auth_token),
      twilio_phone_number: cleanSetting(payload.twilio_phone_number, current.twilio_phone_number),
      twilio_verify_sid: cleanSetting(payload.twilio_verify_sid, current.twilio_verify_sid),
      auto_topup_enabled: payload.auto_topup_enabled !== undefined ? Boolean(payload.auto_topup_enabled) : current.auto_topup_enabled,
      auto_topup_threshold_rides: payload.auto_topup_threshold_rides ? parseInt(payload.auto_topup_threshold_rides, 10) : current.auto_topup_threshold_rides,
      default_auto_topup_plan_id: cleanSetting(payload.default_auto_topup_plan_id, current.default_auto_topup_plan_id),
      grace_rides_limit: payload.grace_rides_limit ? parseInt(payload.grace_rides_limit, 10) : current.grace_rides_limit,
      subscription_rollover_enabled: payload.subscription_rollover_enabled !== undefined ? Boolean(payload.subscription_rollover_enabled) : current.subscription_rollover_enabled,
    };

    await db.updatePlatformSettings(updateData);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'INTEGRATION_SETTINGS_UPDATED',
      resource_type: 'PLATFORM_SETTINGS',
      details: { updatedKeys: Object.keys(payload) },
      ip_address: ipAddress,
    });

    return this.getIntegrationSettings();
  }

  public async getPassengers() {
    return db.getPassengers();
  }

  public async getTransactions() {
    return db.getTransactions();
  }
}

export const adminService = new AdminService();
