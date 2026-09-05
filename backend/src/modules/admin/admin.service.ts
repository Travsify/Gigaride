import { db, PlatformSettingsRow, SubscriptionPlanRow, AdminAuditLogRow, DisputeRow, AdminRole, UserRow, CityZoneRow, PromoCodeRow, DriverPayoutRow, VehicleInspectionRow, BackupSnapshotRow } from '../../database';
import { geoSessionManager } from '../../common/redis';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { broadcastFleetAlert } from '../bidding/bidding.gateway';
import { resendService } from '../notifications/resend.service';
import { twilioService } from '../notifications/twilio.service';
import { korapayService } from '../payments/korapay.service';

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

  public async setPassengerStatus(
    adminUser: { id: string; email: string },
    passengerId: string,
    status: 'ACTIVE' | 'SUSPENDED' | 'BANNED',
    ipAddress?: string
  ) {
    const updated = await db.setUserStatus(passengerId, status);
    if (!updated) throw new Error('Passenger not found.');

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: `PASSENGER_STATUS_${status}`,
      resource_type: 'PASSENGER_PROFILE',
      resource_id: passengerId,
      details: { status },
      ip_address: ipAddress,
    });

    return updated;
  }

  public async creditPassengerWallet(
    adminUser: { id: string; email: string },
    passengerId: string,
    amountNgn: number,
    reason: string,
    ipAddress?: string
  ) {
    if (amountNgn <= 0) throw new Error('Credit amount must be greater than 0.');
    if (!reason || reason.trim().length < 3) throw new Error('Operational reason is required for goodwill wallet credit.');

    const passenger = await db.findUserById(passengerId);
    if (!passenger) throw new Error('Passenger not found.');

    let va = await db.getVirtualAccountByUserId(passengerId);
    if (!va) {
      va = await db.createOrUpdateVirtualAccount({
        id: `va_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        user_id: passengerId,
        account_reference: `ref_va_${Date.now()}`,
        account_number: `100${Math.floor(1000000 + Math.random() * 9000000)}`,
        bank_name: 'Wema Bank / Korapay',
        bank_code: '035',
        account_name: passenger.full_name,
        provider: 'korapay',
        balance_ngn: 0,
        is_active: true,
        created_at: new Date().toISOString(),
      });
    }

    const updatedVa = await db.creditVirtualAccountBalance(passengerId, amountNgn);

    await db.createTransaction({
      id: `tx_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      reference: `ADMIN_CREDIT_${Date.now()}`,
      user_id: passengerId,
      amount_kobo: Math.round(amountNgn * 100),
      status: 'SUCCESS',
      payment_type: 'SUBSCRIPTION_PURCHASE',
      channel: 'ADMIN_GOODWILL',
      meta_data: { reason, admin_id: adminUser.id, admin_email: adminUser.email },
      created_at: new Date().toISOString(),
    });

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'PASSENGER_WALLET_CREDITED',
      resource_type: 'PASSENGER_WALLET',
      resource_id: passengerId,
      details: { amountNgn, reason, newBalance: updatedVa?.balance_ngn },
      ip_address: ipAddress,
    });

    return { passengerId, creditedNgn: amountNgn, newBalance: updatedVa?.balance_ngn };
  }

  public async getAllRides(filter?: { status?: string; search?: string; limit?: number }) {
    return db.getAllRides(filter);
  }

  public async cancelRideByAdmin(
    adminUser: { id: string; email: string },
    rideId: string,
    reason: string,
    ipAddress?: string
  ) {
    const updated = await db.updateRideStatus(rideId, 'CANCELLED');
    if (!updated) throw new Error('Ride not found.');

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'RIDE_CANCELLED_BY_ADMIN',
      resource_type: 'RIDE',
      resource_id: rideId,
      details: { reason },
      ip_address: ipAddress,
    });

    return updated;
  }

  public async getStaffUsers() {
    return db.getStaffUsers();
  }

  public async createStaffUser(
    adminUser: { id: string; email: string },
    payload: { name: string; email: string; phone: string; password: string; admin_role: AdminRole },
    ipAddress?: string
  ) {
    const existingEmail = await db.findUserByEmail(payload.email);
    if (existingEmail) throw new Error('A user with this email address already exists.');

    const existingPhone = await db.findUserByPhone(payload.phone);
    if (existingPhone) throw new Error('A user with this phone number already exists.');

    const passwordHash = await bcrypt.hash(payload.password, 10);
    const staffId = uuidv4();
    const newUser: UserRow = {
      id: staffId,
      role: 'ADMIN',
      admin_role: payload.admin_role,
      full_name: payload.name,
      email: payload.email,
      phone_number: payload.phone,
      password_hash: passwordHash,
      account_status: 'ACTIVE',
      created_at: new Date().toISOString(),
    };

    await db.createUser(newUser);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'STAFF_USER_CREATED',
      resource_type: 'STAFF_USER',
      resource_id: staffId,
      details: { email: payload.email, admin_role: payload.admin_role },
      ip_address: ipAddress,
    });

    return {
      id: newUser.id,
      full_name: newUser.full_name,
      email: newUser.email,
      phone_number: newUser.phone_number,
      admin_role: newUser.admin_role,
      account_status: newUser.account_status,
      created_at: newUser.created_at,
    };
  }

  public async updateStaffRole(
    adminUser: { id: string; email: string },
    staffId: string,
    adminRole: AdminRole,
    ipAddress?: string
  ) {
    const updated = await db.updateStaffRole(staffId, adminRole);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'STAFF_ROLE_UPDATED',
      resource_type: 'STAFF_USER',
      resource_id: staffId,
      details: { newRole: adminRole },
      ip_address: ipAddress,
    });

    return updated;
  }

  public async setStaffStatus(
    adminUser: { id: string; email: string },
    staffId: string,
    status: 'ACTIVE' | 'SUSPENDED',
    ipAddress?: string
  ) {
    const updated = await db.setUserStatus(staffId, status);
    if (!updated) throw new Error('Staff user not found.');

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: `STAFF_STATUS_${status}`,
      resource_type: 'STAFF_USER',
      resource_id: staffId,
      details: { status },
      ip_address: ipAddress,
    });

    return updated;
  }

  public async sendComplianceReminder(
    adminUser: { id: string; email: string },
    driverId: string,
    docType: string = 'Driver License / LASDRI',
    ipAddress?: string
  ) {
    const profile = await db.getDriverProfile(driverId);
    if (!profile) throw new Error('Driver profile not found.');
    const user = await db.findUserById(driverId);
    if (!user) throw new Error('Driver user record not found.');

    // 1. Send SMS reminder
    await twilioService.sendSms(
      user.phone_number,
      `Hello ${user.full_name}, reminder from Giga Ride Compliance Desk: Your ${docType} is approaching expiration. Please renew immediately to avoid dispatch suspension.`
    );

    // 2. Send Email reminder
    if (user.email) {
      await resendService.sendEmail({
        to: user.email,
        subject: `URGENT: Giga Ride Document Renewal Notice (${docType})`,
        html: `
          <div style="font-family: Arial, sans-serif; background: #0F172A; color: #F8FAFC; padding: 24px; border-radius: 16px;">
            <h2 style="color: #F59E0B;">⚠️ Giga Ride Compliance Notice: Document Renewal Required</h2>
            <p>Dear ${user.full_name},</p>
            <p>Our regulatory monitoring system detected that your <strong>${docType}</strong> is due for expiration or has expired.</p>
            <p>Under Lagos State Ministry of Transportation (LASG) guidelines, active commercial drivers must maintain valid LASDRI and FRSC credentials to remain on the dispatch grid.</p>
            <div style="background: #1E293B; border-left: 4px solid #F59E0B; padding: 14px; margin: 16px 0; border-radius: 8px;">
              Please upload your renewed documentation through the Giga Driver App or visit a designated Giga Support Hub.
            </div>
            <p style="color: #94A3B8; font-size: 12px;">Giga Ride Regulatory Compliance Operations Desk</p>
          </div>
        `,
      });
    }

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'COMPLIANCE_REMINDER_DISPATCHED',
      resource_type: 'DRIVER_PROFILE',
      resource_id: driverId,
      details: { docType, phone: user.phone_number, email: user.email },
      ip_address: ipAddress,
    });

    return { success: true, driverId, driverName: user.full_name, docType };
  }

  public async broadcastFleetAlert(
    adminUser: { id: string; email: string },
    alert: { title: string; message: string; target: 'ALL' | 'DRIVERS' | 'PASSENGERS'; severity: 'INFO' | 'WARNING' | 'CRITICAL' },
    ipAddress?: string
  ) {
    const alertPayload = {
      ...alert,
      timestamp: new Date().toISOString(),
      dispatchedBy: adminUser.email,
    };

    broadcastFleetAlert(alert.target, alertPayload);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'FLEET_BROADCAST_SENT',
      resource_type: 'PLATFORM_BROADCAST',
      resource_id: `broadcast_${Date.now()}`,
      details: alertPayload,
      ip_address: ipAddress,
    });

    return { success: true, alert: alertPayload };
  }

  public async getFinancialReconciliation() {
    return db.getFinancialReconciliation();
  }

  public async getTransactions() {
    return db.getTransactions();
  }

  // ==========================================
  // MODULE 1: DRIVER PAYOUTS & SETTLEMENT DESK
  // ==========================================
  public async getDriverPayouts(filter?: 'PENDING' | 'APPROVED' | 'REJECTED') {
    return db.getDriverPayouts(filter ? { status: filter } : undefined);
  }

  public async createDriverPayout(params: {
    driverId: string;
    amountNgn: number;
    bankName: string;
    accountNumber: string;
    accountName: string;
    bankCode?: string;
  }) {
    return db.createDriverPayout({
      driver_id: params.driverId,
      amount_ngn: params.amountNgn,
      bank_name: params.bankName,
      account_number: params.accountNumber,
      account_name: params.accountName,
      bank_code: params.bankCode || '058',
    });
  }

  public async processDriverPayout(
    adminUser: { id: string; email: string },
    payoutId: string,
    action: 'APPROVE' | 'REJECT',
    rejectionReason?: string,
    ipAddress?: string
  ) {
    const payouts = await db.getDriverPayouts();
    const payout = payouts.find((p) => p.id === payoutId);
    if (!payout) throw new Error('Payout request not found.');
    if (payout.status !== 'PENDING') throw new Error(`Payout request is already ${payout.status}.`);

    let transferRef: string | undefined;

    if (action === 'APPROVE') {
      const disburseResult = await korapayService.disbursePayout({
        reference: `payout_${payout.id}_${Date.now()}`,
        amountNgn: payout.amount_ngn,
        bankCode: payout.bank_code || '058',
        accountNumber: payout.account_number,
        accountName: payout.account_name,
      });

      if (!disburseResult.success) {
        throw new Error(`Korapay NIP transfer failed: ${disburseResult.error || 'Unknown provider error'}`);
      }
      transferRef = disburseResult.transferReference;
    }

    const updated = await db.updateDriverPayoutStatus(payoutId, action === 'APPROVE' ? 'APPROVED' : 'REJECTED', rejectionReason);

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: action === 'APPROVE' ? 'DRIVER_PAYOUT_APPROVED' : 'DRIVER_PAYOUT_REJECTED',
      resource_type: 'DRIVER_PAYOUT',
      resource_id: payoutId,
      details: { amount_ngn: payout.amount_ngn, driver_id: payout.driver_id, transfer_ref: transferRef, rejectionReason },
      ip_address: ipAddress,
    });

    return { ...updated, transfer_ref: transferRef };
  }

  // ==========================================
  // MODULE 2: MULTI-CITY & SURCHARGES GEOFENCING
  // ==========================================
  public async getCityZones() {
    return db.getCityZones();
  }

  public async createCityZone(
    adminUser: { id: string; email: string },
    payload: {
      name: string;
      state: string;
      currency?: string;
      petrol_price_ngn: number;
      base_flag_fall_ngn: number;
      per_km_rate_ngn: number;
      per_minute_rate_ngn: number;
      state_levy_ngn: number;
      airport_surcharge_ngn: number;
      toll_surcharge_ngn: number;
      is_active?: boolean;
    },
    ipAddress?: string
  ) {
    const id = `city_${payload.name.toLowerCase().replace(/\s+/g, '_')}`;
    const zone: CityZoneRow = {
      id,
      name: payload.name,
      state: payload.state,
      currency: payload.currency || 'NGN',
      petrol_price_ngn: payload.petrol_price_ngn,
      base_flag_fall_ngn: payload.base_flag_fall_ngn,
      per_km_rate_ngn: payload.per_km_rate_ngn,
      per_minute_rate_ngn: payload.per_minute_rate_ngn,
      state_levy_ngn: payload.state_levy_ngn,
      airport_surcharge_ngn: payload.airport_surcharge_ngn,
      toll_surcharge_ngn: payload.toll_surcharge_ngn,
      is_active: payload.is_active !== undefined ? payload.is_active : true,
      created_at: new Date().toISOString(),
    };
    const created = await db.createCityZone(zone);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'CITY_ZONE_CREATED',
      resource_type: 'CITY_ZONE',
      resource_id: created.id,
      details: payload,
      ip_address: ipAddress,
    });
    return created;
  }

  public async updateCityZone(
    adminUser: { id: string; email: string },
    cityId: string,
    updates: Partial<CityZoneRow>,
    ipAddress?: string
  ) {
    const updated = await db.updateCityZone(cityId, updates);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'CITY_ZONE_UPDATED',
      resource_type: 'CITY_ZONE',
      resource_id: cityId,
      details: updates,
      ip_address: ipAddress,
    });
    return updated;
  }

  // ==========================================
  // MODULE 3: PROMO CODES & MARKETING CAMPAIGNS
  // ==========================================
  public async getPromoCodes() {
    return db.getPromoCodes();
  }

  public async createPromoCode(
    adminUser: { id: string; email: string },
    payload: {
      code: string;
      description?: string;
      discount_type: 'FLAT' | 'PERCENTAGE';
      discount_value: number;
      max_discount_ngn?: number;
      max_uses?: number;
      city?: string;
      expires_at: string;
      is_active?: boolean;
    },
    ipAddress?: string
  ) {
    const promo: PromoCodeRow = {
      id: `promo_${Date.now()}`,
      code: payload.code.toUpperCase(),
      description: payload.description || `${payload.code} Promotion`,
      discount_type: payload.discount_type,
      discount_value: payload.discount_value,
      max_discount_ngn: payload.max_discount_ngn,
      max_uses: payload.max_uses || 1000,
      current_uses: 0,
      city: payload.city,
      is_active: payload.is_active !== undefined ? payload.is_active : true,
      expires_at: payload.expires_at,
      created_at: new Date().toISOString(),
    };
    const created = await db.createPromoCode(promo);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'PROMO_CODE_CREATED',
      resource_type: 'PROMO_CODE',
      resource_id: promo.id,
      details: payload,
      ip_address: ipAddress,
    });
    return promo;
  }

  public async deletePromoCode(
    adminUser: { id: string; email: string },
    promoId: string,
    ipAddress?: string
  ) {
    const deleted = await db.deletePromoCode(promoId);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'PROMO_CODE_DELETED',
      resource_type: 'PROMO_CODE',
      resource_id: promoId,
      details: { deleted },
      ip_address: ipAddress,
    });
    return { success: deleted, promoId };
  }

  public async validatePromoCode(code: string, tripFareNgn: number) {
    return db.validateAndApplyPromo(code, tripFareNgn);
  }

  // ==========================================
  // MODULE 4: DRIVER QUALITY & STRIKE WATCHLIST
  // ==========================================
  public async getDriverQualityWatchlist() {
    return db.getDriverQualityWatchlist();
  }

  // ==========================================
  // MODULE 5: PAYSTACK DIRECT REFUNDS
  // ==========================================
  public async refundPaymentTransaction(
    adminUser: { id: string; email: string },
    transactionId: string,
    reason: string,
    ipAddress?: string
  ) {
    const refunded = await db.refundPaymentTransaction(transactionId, reason);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'PAYMENT_TRANSACTION_REFUNDED',
      resource_type: 'PAYMENT_TRANSACTION',
      resource_id: transactionId,
      details: { reason, amount_ngn: refunded.amount_kobo / 100, reference: refunded.reference },
      ip_address: ipAddress,
    });
    return refunded;
  }

  // ==========================================
  // MODULE 6: PHYSICAL VEHICLE HUB INSPECTION
  // ==========================================
  public async getVehicleInspections(driverId?: string) {
    return db.getVehicleInspections(driverId);
  }

  public async recordVehicleInspection(
    adminUser: { id: string; email: string },
    payload: {
      driver_id: string;
      hub_name: string;
      inspector_name?: string;
      status: 'PASSED' | 'FAILED' | 'PENDING';
      ac_functional: boolean;
      tires_healthy: boolean;
      exterior_clean: boolean;
      lights_functional: boolean;
      notes?: string;
    },
    ipAddress?: string
  ) {
    const inspection = await db.recordVehicleInspection({
      driver_id: payload.driver_id,
      hub_name: payload.hub_name,
      inspector_name: payload.inspector_name || adminUser.email,
      status: payload.status,
      ac_functional: payload.ac_functional,
      tires_healthy: payload.tires_healthy,
      exterior_clean: payload.exterior_clean,
      lights_functional: payload.lights_functional,
      notes: payload.notes,
      inspected_at: new Date().toISOString(),
    });

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'VEHICLE_INSPECTION_RECORDED',
      resource_type: 'VEHICLE_INSPECTION',
      resource_id: inspection.id,
      details: { driver_id: payload.driver_id, status: payload.status, hub_name: payload.hub_name },
      ip_address: ipAddress,
    });

    return inspection;
  }

  // ==========================================
  // MODULE 7: BACKUP SNAPSHOTS & DISASTER RECOVERY
  // ==========================================
  public async createBackupSnapshot(
    adminUser: { id: string; email: string },
    ipAddress?: string
  ) {
    const { snapshot, dataJson } = await db.createBackupSnapshot(adminUser.email);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'DATABASE_BACKUP_CREATED',
      resource_type: 'DATABASE_BACKUP',
      resource_id: snapshot.id,
      details: { filename: snapshot.filename, size_bytes: snapshot.size_bytes, record_count: snapshot.record_count },
      ip_address: ipAddress,
    });
    return { snapshot, dataJson };
  }

  public async getBackupSnapshots() {
    return db.getBackupSnapshots();
  }

  // ==========================================
  // MODULE 8: DEMAND HEATMAPS, SCHEDULED TRIPS & PASSENGER COMMUTE PASSES
  // ==========================================
  public async getDemandHeatmap() {
    return db.getDemandHeatmap();
  }

  public async getScheduledRides() {
    return db.getScheduledRides();
  }

  public async assignDriverToScheduledRide(
    adminUser: { id: string; email: string },
    rideId: string,
    driverId: string,
    ipAddress?: string
  ) {
    const updated = await db.assignDriverToScheduledRide(rideId, driverId);
    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'SCHEDULED_RIDE_DRIVER_ASSIGNED',
      resource_type: 'RIDE',
      resource_id: rideId,
      details: { driverId },
      ip_address: ipAddress,
    });
    return updated;
  }

  public async createRiderPass(
    adminUser: { id: string; email: string },
    payload: {
      rider_id: string;
      pass_name: string;
      discount_percent: number;
      max_discount_per_ride_ngn: number;
      rides_remaining: number;
      corridor?: string;
      duration_days: number;
      price_kobo: number;
    },
    ipAddress?: string
  ) {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + (payload.duration_days || 30) * 24 * 60 * 60 * 1000).toISOString();
    const entry = await db.createRiderPass({
      rider_id: payload.rider_id,
      pass_name: payload.pass_name,
      discount_percent: payload.discount_percent,
      max_discount_per_ride_ngn: payload.max_discount_per_ride_ngn,
      rides_remaining: payload.rides_remaining,
      corridor: payload.corridor || 'All Corridors',
      starts_at: now.toISOString(),
      expires_at: expiresAt,
      price_kobo: payload.price_kobo,
      status: 'ACTIVE',
    });

    await db.logAdminAudit({
      admin_id: adminUser.id,
      admin_email: adminUser.email,
      action: 'RIDER_COMMUTE_PASS_CREATED',
      resource_type: 'RIDER_PASS',
      resource_id: entry.id,
      details: { rider_id: payload.rider_id, pass_name: payload.pass_name },
      ip_address: ipAddress,
    });
    return entry;
  }

  public async getAllRiderPasses() {
    return db.getAllRiderPasses();
  }
}

export const adminService = new AdminService();
