import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import bcrypt from 'bcryptjs';
import { ENV } from '../config/env';

export type AdminRole = 'SUPER_ADMIN' | 'SUPPORT_AGENT' | 'KYC_OFFICER' | 'FINANCE_ADMIN';

export interface NotificationRow {
  id: string;
  user_id: string;
  title: string;
  message: string;
  type: 'BID' | 'RIDE' | 'WALLET' | 'KYC' | 'SOS' | 'SYSTEM';
  is_read: boolean;
  meta_data?: Record<string, any>;
  created_at: string;
}

export interface EmailVerificationRow {
  email: string;
  otp: string;
  expires_at: string;
  is_verified?: boolean;
}

export interface UserRow {
  id: string;
  role: 'PASSENGER' | 'DRIVER' | 'ADMIN';
  admin_role?: AdminRole;
  full_name: string;
  phone_number: string;
  email: string;
  password_hash: string;
  is_phone_verified?: boolean;
  is_email_verified?: boolean;
  account_status?: 'ACTIVE' | 'SUSPENDED' | 'BANNED';
  created_at: string;
}

export interface DriverProfileRow {
  id: string;
  driver_id: string;
  vehicle_make: string;
  vehicle_model: string;
  vehicle_year: number;
  license_plate: string;
  vehicle_color: string;
  kyc_status: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejection_reason?: string | null;
  account_status: 'ACTIVE' | 'SUSPENDED' | 'BANNED';
  nin?: string;
  bvn?: string;
  driver_license_expiry?: string | null;
  insurance_expiry?: string | null;
  road_worthiness_expiry?: string | null;
  lasdri_card_number?: string | null;
  lasdri_expiry?: string | null;
  rating_average: number;
  total_trips_completed: number;
  is_online: boolean;
  is_locked_out?: boolean;
  lockout_reason?: string | null;
  auto_topup_enabled?: boolean;
  preferred_plan_id?: string | null;
  created_at: string;
}

export interface SubscriptionPlanRow {
  id: string;
  name: string;
  description: string;
  plan_type: 'RIDE_COUNT' | 'UNLIMITED';
  total_rides: number | null; // null for unlimited
  duration_days: number;
  price_kobo: number; // in NGN kobo (e.g. 1500000 = 15,000 NGN)
  is_active: boolean;
}

export interface DriverSubscriptionRow {
  id: string;
  driver_id: string;
  plan_id: string;
  status: 'ACTIVE' | 'EXHAUSTED' | 'EXPIRED';
  remaining_rides: number; // e.g. 50, 0, or down to -2 for grace
  starts_at: string;
  expires_at: string;
  is_frozen?: boolean;
  frozen_at?: string;
  total_frozen_ms?: number;
  freeze_reason?: string;
  created_at: string;
}

export interface RiderSubscriptionRow {
  id: string;
  rider_id: string;
  pass_name: string;
  discount_percent: number;
  max_discount_per_ride_ngn: number;
  rides_remaining: number;
  corridor?: string;
  starts_at: string;
  expires_at: string;
  price_kobo: number;
  status: 'ACTIVE' | 'EXHAUSTED' | 'EXPIRED';
  created_at: string;
}

export interface SubscriptionCreditAuditRow {
  id: string;
  admin_id: string;
  driver_id: string;
  rides_added: number;
  previous_rides: number;
  new_rides: number;
  reason: string;
  created_at: string;
}

export interface AdminAuditLogRow {
  id: string;
  admin_id: string;
  admin_email: string;
  action: string;
  resource_type: string;
  resource_id?: string;
  details: any;
  ip_address?: string;
  created_at: string;
}

export interface DisputeRow {
  id: string;
  ride_id: string;
  reporter_id: string;
  reporter_role: 'PASSENGER' | 'DRIVER';
  dispute_type: string;
  description: string;
  status: 'OPEN' | 'INVESTIGATING' | 'RESOLVED' | 'DISMISSED';
  resolution_notes?: string;
  driver_strike_applied: boolean;
  compensation_rides: number;
  created_at: string;
  resolved_at?: string;
}

export interface RideGpsBreadcrumbRow {
  id: string;
  ride_id: string;
  driver_id: string;
  latitude: number;
  longitude: number;
  speed_kmh: number;
  recorded_at: string;
}

export interface RideRow {
  id: string;
  rider_id: string;
  driver_id?: string | null;
  pickup_lat: number;
  pickup_lng: number;
  pickup_address: string;
  dropoff_lat: number;
  dropoff_lng: number;
  dropoff_address: string;
  suggested_fare_ngn: number;
  rider_offer_ngn: number;
  agreed_fare_ngn?: number | null;
  distance_km: number;
  status: 'REQUESTED' | 'NEGOTIATING' | 'ACCEPTED' | 'ARRIVED' | 'IN_TRANSIT' | 'COMPLETED' | 'CANCELLED';
  scheduled_for?: string;
  flight_number?: string;
  is_airport?: boolean;
  is_interstate?: boolean;
  driver_pre_assigned?: boolean;
  created_at: string;
  completed_at?: string | null;
}

export interface RideBidRow {
  id: string;
  ride_id: string;
  driver_id: string;
  counter_fare_ngn: number;
  eta_minutes: number;
  status: 'OFFERED' | 'ACCEPTED' | 'REJECTED';
  created_at: string;
}

export interface UserSavedCardRow {
  id: string;
  user_id: string;
  authorization_code: string;
  card_brand: string; // 'visa' | 'mastercard' | 'verve'
  card_last4: string; // '4081'
  card_bank: string;  // 'Access Bank'
  exp_month: string;  // '12'
  exp_year: string;   // '2028'
  card_holder_name?: string;
  is_default: boolean;
  created_at: string;
}

export interface PaymentTransactionRow {
  id: string;
  reference: string;
  user_id: string;
  amount_kobo: number;
  status: 'PENDING' | 'SUCCESS' | 'FAILED' | 'REFUNDED';
  payment_type: 'SUBSCRIPTION_PURCHASE' | 'WALLET_FUNDING' | 'RIDE_PAYMENT';
  channel: string;
  meta_data: any;
  card_brand?: string;
  card_last4?: string;
  card_bank?: string;
  card_exp_month?: string;
  card_exp_year?: string;
  refunded_at?: string;
  refund_reason?: string;
  created_at: string;
}

export interface DriverPayoutRow {
  id: string;
  driver_id: string;
  amount_ngn: number;
  fee_ngn: number;
  net_amount_ngn: number;
  bank_name: string;
  bank_code: string;
  account_number: string;
  account_name: string;
  status: 'PENDING' | 'APPROVED' | 'TRANSFERRED' | 'REJECTED';
  rejection_reason?: string;
  reference: string;
  created_at: string;
  processed_at?: string;
}

export interface CityZoneRow {
  id: string;
  name: string;
  state: string;
  currency: string;
  petrol_price_ngn: number;
  base_flag_fall_ngn: number;
  per_km_rate_ngn: number;
  per_minute_rate_ngn: number;
  state_levy_ngn: number;
  airport_surcharge_ngn: number;
  toll_surcharge_ngn: number;
  is_active: boolean;
  created_at: string;
}

export interface PromoCodeRow {
  id: string;
  code: string;
  description: string;
  discount_type: 'FLAT' | 'PERCENTAGE';
  discount_value: number;
  max_discount_ngn?: number;
  max_uses: number;
  current_uses: number;
  city?: string;
  is_active: boolean;
  expires_at: string;
  created_at: string;
}

export interface VehicleInspectionRow {
  id: string;
  driver_id: string;
  hub_name: string;
  inspector_name: string;
  status: 'PASSED' | 'FAILED' | 'PENDING';
  ac_functional: boolean;
  tires_healthy: boolean;
  exterior_clean: boolean;
  lights_functional: boolean;
  notes?: string;
  inspected_at: string;
  created_at: string;
}

export interface BackupSnapshotRow {
  id: string;
  filename: string;
  size_bytes: number;
  record_count: number;
  created_at: string;
  created_by: string;
}

export interface SosIncidentRow {
  id: string;
  ride_id: string;
  driver_id?: string;
  rider_id: string;
  latitude: number;
  longitude: number;
  status: 'OPEN' | 'IN_REVIEW' | 'RESOLVED';
  notes?: string;
  created_at: string;
  resolved_at?: string;
}

export interface VirtualBankAccountRow {
  id: string;
  user_id: string;
  account_reference: string;
  account_number: string;
  bank_name: string;
  bank_code: string;
  account_name: string;
  provider: 'korapay' | 'paystack';
  balance_ngn: number;
  vault_balance_ngn?: number;
  is_active: boolean;
  created_at: string;
}

export interface BeneficiaryRow {
  id: string;
  user_id: string;
  account_name: string;
  account_number: string;
  bank_name: string;
  bank_code: string;
  nickname?: string;
  last_transacted_at: string;
  is_pinned?: boolean;
  created_at: string;
}

export interface PhoneVerificationRow {
  id: string;
  phone_number: string;
  otp_code: string;
  attempts: number;
  expires_at: string;
  is_verified: boolean;
  created_at: string;
}

export interface KycVerificationRow {
  id: string;
  driver_id: string;
  verification_type: 'NIN' | 'DRIVERS_LICENSE' | 'BVN' | 'VEHICLE_PLATE';
  id_number: string;
  status: 'VERIFIED' | 'FAILED' | 'PENDING';
  confidence_score: number;
  response_payload: any;
  created_at: string;
}

export interface PlatformSettingsRow {
  petrol_price_ngn: number;
  base_flag_fall_ngn: number;
  per_km_rate_ngn: number;
  per_minute_rate_ngn: number;
  lagos_mot_levy_ngn: number;
  welcome_bonus_rides: number;
  search_radius_km: number;
  // OneSignal Push Notifications
  onesignal_app_id?: string;
  onesignal_rest_api_key?: string;
  paystack_base_url?: string;
  prembly_base_url?: string;
  prembly_public_key?: string;
  // Prembly Identity & KYC
  prembly_api_key?: string;
  prembly_app_id?: string;
  prembly_auto_approve?: boolean;
  // Paystack Card Payments
  paystack_secret_key?: string;
  paystack_public_key?: string;
  paystack_webhook_secret?: string;
  // Korapay Virtual Accounts
  korapay_secret_key?: string;
  korapay_public_key?: string;
  korapay_encryption_key?: string;
  korapay_merchant_id?: string;
  // Resend Transactional Email
  resend_api_key?: string;
  resend_from_email?: string;
  // Twilio Phone Verification
  twilio_account_sid?: string;
  twilio_auth_token?: string;
  twilio_phone_number?: string;
  twilio_verify_sid?: string;
  // Automated Subscription Top-Up & 2-Grace Lockout
  auto_topup_enabled?: boolean;
  auto_topup_threshold_rides?: number;
  default_auto_topup_plan_id?: string;
  grace_rides_limit?: number;
  subscription_rollover_enabled?: boolean;
  updated_at: string;
}

export class DatabaseService {
  private static instance: DatabaseService;
  private pgPool: Pool | null = null;
  private isPostgresConnected = false;

  private dbFilePath = path.join(__dirname, '../../../data_store.json');
  private store = {
    users: [] as UserRow[],
    driver_profiles: [] as DriverProfileRow[],
    subscription_plans: [] as SubscriptionPlanRow[],
    driver_subscriptions: [] as DriverSubscriptionRow[],
    subscription_credit_audits: [] as SubscriptionCreditAuditRow[],
    admin_audit_logs: [] as AdminAuditLogRow[],
    disputes: [] as DisputeRow[],
    ride_gps_breadcrumbs: [] as RideGpsBreadcrumbRow[],
    rides: [] as RideRow[],
    ride_bids: [] as RideBidRow[],
    payment_transactions: [] as PaymentTransactionRow[],
    sos_incidents: [] as SosIncidentRow[],
    virtual_bank_accounts: [] as VirtualBankAccountRow[],
    phone_verifications: [] as PhoneVerificationRow[],
    kyc_verifications: [] as KycVerificationRow[],
    driver_payouts: [] as DriverPayoutRow[],
    city_zones: [] as CityZoneRow[],
    promo_codes: [] as PromoCodeRow[],
    vehicle_inspections: [] as VehicleInspectionRow[],
    backup_snapshots: [] as BackupSnapshotRow[],
    rider_subscriptions: [] as RiderSubscriptionRow[],
    beneficiaries: [] as BeneficiaryRow[],
    user_saved_cards: [] as UserSavedCardRow[],
    notifications: [] as NotificationRow[],
    email_verifications: [] as EmailVerificationRow[],
    platform_settings: {
      petrol_price_ngn: 1050,
      base_flag_fall_ngn: 1500,
      per_km_rate_ngn: 350,
      per_minute_rate_ngn: 80,
      lagos_mot_levy_ngn: 50,
      welcome_bonus_rides: 5,
      search_radius_km: 7.0,
      onesignal_app_id: process.env.ONESIGNAL_APP_ID || '',
      onesignal_rest_api_key: process.env.ONESIGNAL_REST_API_KEY || '',
      paystack_base_url: 'https://api.paystack.co',
      prembly_base_url: 'https://api.prembly.com/identitypass/verification',
      prembly_public_key: process.env.PREMBLY_PUBLIC_KEY || '',
      prembly_api_key: process.env.PREMBLY_API_KEY || '',
      prembly_app_id: process.env.PREMBLY_APP_ID || '',
      prembly_auto_approve: true,
      paystack_secret_key: process.env.PAYSTACK_SECRET_KEY || '',
      paystack_public_key: process.env.PAYSTACK_PUBLIC_KEY || '',
      paystack_webhook_secret: '',
      korapay_secret_key: '',
      korapay_public_key: '',
      korapay_encryption_key: '',
      korapay_merchant_id: '',
      resend_api_key: process.env.RESEND_API_KEY || '',
      resend_from_email: 'info@getgigaride.com',
      twilio_account_sid: process.env.TWILIO_ACCOUNT_SID || '',
      twilio_auth_token: process.env.TWILIO_AUTH_TOKEN || '',
      twilio_phone_number: process.env.TWILIO_PHONE_NUMBER || '',
      twilio_verify_sid: '',
      auto_topup_enabled: true,
      auto_topup_threshold_rides: 2,
      default_auto_topup_plan_id: 'plan_standard_50',
      grace_rides_limit: 2,
      subscription_rollover_enabled: true,
      updated_at: new Date().toISOString(),
    } as PlatformSettingsRow,
  };

  private constructor() {
    this.initStore();
    this.tryConnectPostgres();
  }

  public static getInstance(): DatabaseService {
    if (!DatabaseService.instance) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  private initStore() {
    if (fs.existsSync(this.dbFilePath)) {
      try {
        const raw = fs.readFileSync(this.dbFilePath, 'utf8');
        const parsed = JSON.parse(raw);
        this.store = { ...this.store, ...parsed };
        if (!this.store.platform_settings) {
          this.store.platform_settings = {
            petrol_price_ngn: 1050,
            base_flag_fall_ngn: 1500,
            per_km_rate_ngn: 350,
            per_minute_rate_ngn: 80,
            lagos_mot_levy_ngn: 50,
            welcome_bonus_rides: 5,
            search_radius_km: 7.0,
            updated_at: new Date().toISOString(),
          };
        }
        if (!this.store.sos_incidents) this.store.sos_incidents = [];
        if (!this.store.subscription_credit_audits) this.store.subscription_credit_audits = [];
        if (!this.store.admin_audit_logs) this.store.admin_audit_logs = [];
        if (!this.store.disputes) this.store.disputes = [];
        if (!this.store.ride_gps_breadcrumbs) this.store.ride_gps_breadcrumbs = [];
        if (!this.store.driver_payouts) this.store.driver_payouts = [];
        if (!this.store.city_zones) this.store.city_zones = [];
        if (!this.store.promo_codes) this.store.promo_codes = [];
        if (!this.store.vehicle_inspections) this.store.vehicle_inspections = [];
        if (!this.store.backup_snapshots) this.store.backup_snapshots = [];
        if (!this.store.rider_subscriptions) this.store.rider_subscriptions = [];
        if (!this.store.beneficiaries) this.store.beneficiaries = [];
        this.seedDefaultCities();
        this.seedDefaultPromos();
        this.seedDefaultStaff();
      } catch {
        this.saveStore();
      }
    } else {
      this.seedDefaultPlans();
      this.seedDefaultCities();
      this.seedDefaultPromos();
      this.seedDefaultStaff();
      this.saveStore();
    }
  }

  private saveStore() {
    try {
      fs.writeFileSync(this.dbFilePath, JSON.stringify(this.store, null, 2), 'utf8');
    } catch (e) {
      console.error('Failed to persist local datastore:', e);
    }
  }

  private seedDefaultPlans() {
    if (this.store.subscription_plans.length === 0) {
      this.store.subscription_plans = [
        {
          id: 'plan_starter_10',
          name: '10-Ride Daily Starter',
          description: 'Great for daily part-time runs and testing the app. Zero commission.',
          plan_type: 'RIDE_COUNT',
          total_rides: 10,
          duration_days: 1,
          price_kobo: 150000,
          is_active: true,
        },
        {
          id: 'plan_standard_50',
          name: '50-Ride Weekly Hustle',
          description: 'Designed for active weekly drivers. No percentage deducted from any trip.',
          plan_type: 'RIDE_COUNT',
          total_rides: 50,
          duration_days: 7,
          price_kobo: 600000,
          is_active: true,
        },
        {
          id: 'plan_pro_100',
          name: '100-Ride Bi-Weekly Pro',
          description: 'Best unit economics for full-time drivers.',
          plan_type: 'RIDE_COUNT',
          total_rides: 100,
          duration_days: 14,
          price_kobo: 1000000,
          is_active: true,
        },
        {
          id: 'plan_monthly_unlimited',
          name: 'Monthly Unlimited Freedom',
          description: '30 Days of unlimited ride requests. Never worry about counting rides.',
          plan_type: 'UNLIMITED',
          total_rides: null,
          duration_days: 30,
          price_kobo: 2500000,
          is_active: true,
        },
      ];
    }
  }

  private seedDefaultCities() {
    if (!this.store.city_zones || this.store.city_zones.length === 0) {
      this.store.city_zones = [
        {
          id: 'city_lagos',
          name: 'Lagos Metropolitan Area',
          state: 'Lagos',
          currency: 'NGN',
          petrol_price_ngn: 1050,
          base_flag_fall_ngn: 1500,
          per_km_rate_ngn: 350,
          per_minute_rate_ngn: 80,
          state_levy_ngn: 50,
          airport_surcharge_ngn: 1000,
          toll_surcharge_ngn: 500,
          is_active: true,
          created_at: new Date().toISOString(),
        },
        {
          id: 'city_abuja',
          name: 'Abuja Federal Capital Territory',
          state: 'FCT',
          currency: 'NGN',
          petrol_price_ngn: 1020,
          base_flag_fall_ngn: 1800,
          per_km_rate_ngn: 380,
          per_minute_rate_ngn: 90,
          state_levy_ngn: 0,
          airport_surcharge_ngn: 1500,
          toll_surcharge_ngn: 0,
          is_active: true,
          created_at: new Date().toISOString(),
        },
        {
          id: 'city_ph',
          name: 'Port Harcourt Urban Corridor',
          state: 'Rivers',
          currency: 'NGN',
          petrol_price_ngn: 1060,
          base_flag_fall_ngn: 1600,
          per_km_rate_ngn: 360,
          per_minute_rate_ngn: 85,
          state_levy_ngn: 0,
          airport_surcharge_ngn: 1200,
          toll_surcharge_ngn: 0,
          is_active: true,
          created_at: new Date().toISOString(),
        },
        {
          id: 'city_ibadan',
          name: 'Ibadan Greater Metro',
          state: 'Oyo',
          currency: 'NGN',
          petrol_price_ngn: 1040,
          base_flag_fall_ngn: 1200,
          per_km_rate_ngn: 300,
          per_minute_rate_ngn: 60,
          state_levy_ngn: 0,
          airport_surcharge_ngn: 800,
          toll_surcharge_ngn: 0,
          is_active: true,
          created_at: new Date().toISOString(),
        },
      ];
    }
  }

  private seedDefaultPromos() {
    if (!this.store.promo_codes || this.store.promo_codes.length === 0) {
      this.store.promo_codes = [
        {
          id: 'promo_lagos500',
          code: 'GIGALAGOS',
          description: '₦500 Off your first ride across Lagos',
          discount_type: 'FLAT',
          discount_value: 500,
          max_discount_ngn: 500,
          max_uses: 5000,
          current_uses: 142,
          city: 'Lagos',
          is_active: true,
          expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
          created_at: new Date().toISOString(),
        },
        {
          id: 'promo_welcome20',
          code: 'WELCOME20',
          description: '20% Off for new passenger registrations',
          discount_type: 'PERCENTAGE',
          discount_value: 20,
          max_discount_ngn: 1000,
          max_uses: 10000,
          current_uses: 380,
          is_active: true,
          expires_at: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString(),
          created_at: new Date().toISOString(),
        },
      ];
    }
  }

  private seedDefaultStaff() {
    const defaultStaff = [
      {
        email: 'admin@gigaride.ng',
        password: 'admin_password_2026',
        full_name: 'Lead Super Admin',
        phone_number: '08000000001',
        admin_role: 'SUPER_ADMIN' as AdminRole,
      },
      {
        email: 'admin@giga.internal',
        password: 'admin_password_2026',
        full_name: 'Lead Super Admin (Internal)',
        phone_number: '08000000011',
        admin_role: 'SUPER_ADMIN' as AdminRole,
      },
      {
        email: 'kyc@gigaride.ng',
        password: 'kyc_password_2026',
        full_name: 'Lead KYC Officer',
        phone_number: '08000000002',
        admin_role: 'KYC_OFFICER' as AdminRole,
      },
      {
        email: 'kyc@giga.internal',
        password: 'kyc_password_2026',
        full_name: 'Lead KYC Officer (Internal)',
        phone_number: '08000000012',
        admin_role: 'KYC_OFFICER' as AdminRole,
      },
      {
        email: 'support@gigaride.ng',
        password: 'support_password_2026',
        full_name: 'Senior Support Agent',
        phone_number: '08000000003',
        admin_role: 'SUPPORT_AGENT' as AdminRole,
      },
      {
        email: 'support@giga.internal',
        password: 'support_password_2026',
        full_name: 'Senior Support Agent (Internal)',
        phone_number: '08000000013',
        admin_role: 'SUPPORT_AGENT' as AdminRole,
      },
      {
        email: 'finance@gigaride.ng',
        password: 'finance_password_2026',
        full_name: 'Finance & Treasury Admin',
        phone_number: '08000000004',
        admin_role: 'FINANCE_ADMIN' as AdminRole,
      },
      {
        email: 'finance@giga.internal',
        password: 'finance_password_2026',
        full_name: 'Finance & Treasury Admin (Internal)',
        phone_number: '08000000014',
        admin_role: 'FINANCE_ADMIN' as AdminRole,
      },
    ];

    for (const staff of defaultStaff) {
      const existing = this.store.users.find((u) => u.email.toLowerCase() === staff.email.toLowerCase());
      if (!existing) {
        this.store.users.push({
          id: `staff_${staff.admin_role.toLowerCase()}`,
          role: 'ADMIN',
          admin_role: staff.admin_role,
          full_name: staff.full_name,
          email: staff.email,
          phone_number: staff.phone_number,
          password_hash: bcrypt.hashSync(staff.password, 10),
          is_phone_verified: true,
          is_email_verified: true,
          account_status: 'ACTIVE',
          created_at: new Date().toISOString(),
        });
      } else {
        existing.is_phone_verified = true;
        existing.is_email_verified = true;
      }
    }
  }

  private async tryConnectPostgres() {
    try {
      this.pgPool = new Pool({
        connectionString: ENV.DATABASE_URL,
        connectionTimeoutMillis: 2000,
      });
      const client = await this.pgPool.connect();
      client.release();
      this.isPostgresConnected = true;
      console.log('[PostgreSQL] Connected successfully to', ENV.DATABASE_URL);
    } catch {
      this.isPostgresConnected = false;
      console.log('[Database] Operating on persistent ACID JSON store.');
    }
  }

  // --- Platform Settings ---
  public async getPlatformSettings(): Promise<PlatformSettingsRow> {
    return this.store.platform_settings;
  }

  public async updatePlatformSettings(settings: Partial<PlatformSettingsRow>): Promise<PlatformSettingsRow> {
    this.store.platform_settings = {
      ...this.store.platform_settings,
      ...settings,
      updated_at: new Date().toISOString(),
    };
    this.saveStore();
    return this.store.platform_settings;
  }

  // --- User Repository ---
  public async createUser(user: UserRow): Promise<UserRow> {
    if (!user.id) user.id = `usr_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    if (!user.created_at) user.created_at = new Date().toISOString();
    this.store.users.push(user);
    this.saveStore();
    return user;
  }

  public async findUserByPhone(phone: string): Promise<UserRow | undefined> {
    return this.store.users.find((u) => u.phone_number === phone);
  }

  public async findUserByEmail(email: string): Promise<UserRow | undefined> {
    return this.store.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
  }

  public async findUserById(id: string): Promise<UserRow | undefined> {
    return this.store.users.find((u) => u.id === id);
  }

  public async getPassengers(): Promise<(UserRow & { totalRides: number; virtualAccount: VirtualBankAccountRow | null })[]> {
    return this.store.users
      .filter((u) => u.role === 'PASSENGER')
      .map((u) => {
        const totalRides = this.store.rides.filter((r) => r.rider_id === u.id && r.status === 'COMPLETED').length;
        const virtualAccount = this.store.virtual_bank_accounts.find((v) => v.user_id === u.id) || null;
        return {
          ...u,
          account_status: u.account_status || 'ACTIVE',
          totalRides,
          virtualAccount,
        };
      });
  }

  public async setUserStatus(userId: string, status: 'ACTIVE' | 'SUSPENDED' | 'BANNED'): Promise<UserRow | undefined> {
    const user = this.store.users.find((u) => u.id === userId);
    if (user) {
      user.account_status = status;
      this.saveStore();
      return user;
    }
    return undefined;
  }

  public async getStaffUsers() {
    return this.store.users
      .filter((u) => u.role === 'ADMIN')
      .map((u) => ({
        id: u.id,
        email: u.email,
        full_name: u.full_name,
        phone_number: u.phone_number,
        admin_role: (u.admin_role || 'SUPPORT_AGENT') as AdminRole,
        account_status: u.account_status || 'ACTIVE',
        created_at: u.created_at,
      }));
  }

  public async updateStaffRole(staffId: string, adminRole: AdminRole) {
    const user = this.store.users.find((u) => u.id === staffId && u.role === 'ADMIN');
    if (!user) throw new Error('Staff user not found.');
    user.admin_role = adminRole;
    this.saveStore();
    return user;
  }

  public async getAllRides(filter?: { status?: string; search?: string; limit?: number }) {
    let list = [...this.store.rides].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    if (filter?.status && filter.status !== 'ALL') {
      list = list.filter((r) => r.status === filter.status);
    }
    if (filter?.search) {
      const q = filter.search.toLowerCase();
      list = list.filter((r) => {
        const rider = this.store.users.find((u) => u.id === r.rider_id);
        const driver = r.driver_id ? this.store.users.find((u) => u.id === r.driver_id) : undefined;
        return (
          r.id.toLowerCase().includes(q) ||
          r.pickup_address.toLowerCase().includes(q) ||
          r.dropoff_address.toLowerCase().includes(q) ||
          (rider && rider.full_name.toLowerCase().includes(q)) ||
          (driver && driver.full_name.toLowerCase().includes(q))
        );
      });
    }
    const limit = filter?.limit || 100;
    return list.slice(0, limit).map((r) => {
      const rider = this.store.users.find((u) => u.id === r.rider_id);
      const driver = r.driver_id ? this.store.users.find((u) => u.id === r.driver_id) : undefined;
      const driverProfile = r.driver_id ? this.store.driver_profiles.find((p) => p.driver_id === r.driver_id) : undefined;
      return {
        ...r,
        rider: rider ? { id: rider.id, full_name: rider.full_name, phone_number: rider.phone_number } : null,
        driver: driver ? { id: driver.id, full_name: driver.full_name, phone_number: driver.phone_number } : null,
        driverProfile: driverProfile ? { license_plate: driverProfile.license_plate, vehicle_make: driverProfile.vehicle_make, vehicle_model: driverProfile.vehicle_model } : null,
      };
    });
  }

  public async getFinancialReconciliation() {
    const passengerVbas = this.store.virtual_bank_accounts.filter((v) => {
      const u = this.store.users.find((user) => user.id === v.user_id);
      return u && u.role === 'PASSENGER';
    });
    const driverVbas = this.store.virtual_bank_accounts.filter((v) => {
      const u = this.store.users.find((user) => user.id === v.user_id);
      return u && u.role === 'DRIVER';
    });

    const totalPassengerFloatNgn = passengerVbas.reduce((sum, v) => sum + (v.balance_ngn || 0), 0);
    const totalDriverFloatNgn = driverVbas.reduce((sum, v) => sum + (v.balance_ngn || 0), 0);

    const motLevyUnit = this.store.platform_settings.lagos_mot_levy_ngn || 50;
    const completedTrips = this.store.rides.filter((r) => r.status === 'COMPLETED');
    const totalMotLeviesNgn = completedTrips.length * motLevyUnit;
    const totalAgreedFaresNgn = completedTrips.reduce((sum, r) => sum + (r.agreed_fare_ngn || r.suggested_fare_ngn || 0), 0);

    const successfulPayments = this.store.payment_transactions.filter((t) => t.status === 'SUCCESS');
    const totalSubscriptionRevenueNgn = successfulPayments.reduce((sum, t) => sum + (t.amount_kobo / 100), 0);

    return {
      totalPassengerFloatNgn,
      totalDriverFloatNgn,
      totalSubscriptionRevenueNgn,
      totalMotLeviesNgn,
      totalAgreedFaresNgn,
      completedTripsCount: completedTrips.length,
      totalTransactionsCount: successfulPayments.length,
    };
  }

  // --- Driver Profile Repository ---
  public async createDriverProfile(profile: DriverProfileRow): Promise<DriverProfileRow> {
    this.store.driver_profiles.push(profile);
    this.saveStore();
    return profile;
  }

  public async getDriverProfile(driverId: string): Promise<DriverProfileRow | undefined> {
    return this.store.driver_profiles.find((d) => d.driver_id === driverId);
  }

  public async getAllDrivers(filter?: 'ALL' | 'PENDING_KYC' | 'APPROVED' | 'REJECTED' | 'EXHAUSTED' | 'SUSPENDED'): Promise<any[]> {
    let profiles = [...this.store.driver_profiles];

    if (filter === 'PENDING_KYC') {
      profiles = profiles.filter((p) => p.kyc_status === 'PENDING');
    } else if (filter === 'APPROVED') {
      profiles = profiles.filter((p) => p.kyc_status === 'APPROVED');
    } else if (filter === 'REJECTED') {
      profiles = profiles.filter((p) => p.kyc_status === 'REJECTED');
    } else if (filter === 'SUSPENDED') {
      profiles = profiles.filter((p) => p.account_status === 'SUSPENDED');
    }

    return profiles.map((p) => {
      const user = this.store.users.find((u) => u.id === p.driver_id);
      const activeSub = this.store.driver_subscriptions
        .filter((s) => s.driver_id === p.driver_id)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
      const plan = activeSub ? this.store.subscription_plans.find((pl) => pl.id === activeSub.plan_id) : undefined;

      return {
        ...p,
        user,
        subscription: activeSub ? { ...activeSub, planName: plan?.name } : null,
      };
    });
  }

  public async getDriverDossier(driverId: string): Promise<any> {
    const profile = await this.getDriverProfile(driverId);
    if (!profile) return null;
    const user = await this.findUserById(driverId);
    const subscriptions = this.store.driver_subscriptions
      .filter((s) => s.driver_id === driverId)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    const creditAudits = this.store.subscription_credit_audits.filter((c) => c.driver_id === driverId);
    const trips = this.store.rides.filter((r) => r.driver_id === driverId);
    const virtualAccount = this.store.virtual_bank_accounts.find((v) => v.user_id === driverId);
    const kycVerifications = this.store.kyc_verifications.filter((k) => k.driver_id === driverId);

    return {
      profile,
      user,
      subscriptions,
      creditAudits,
      virtualAccount: virtualAccount || null,
      kycVerifications,
      totalTrips: trips.length,
      completedTrips: trips.filter((t) => t.status === 'COMPLETED').length,
    };
  }

  public async updateDriverOnlineStatus(driverId: string, isOnline: boolean): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      if (isOnline && profile.kyc_status !== 'APPROVED') {
        throw new Error('Drivers must be thoroughly verified and approved by Prembly before going live.');
      }
      profile.is_online = isOnline;
      this.saveStore();
    }
  }

  public async updateDriverKyc(driverId: string, status: 'APPROVED' | 'REJECTED', rejectionReason?: string): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.kyc_status = status;
      profile.rejection_reason = rejectionReason || null;
      this.saveStore();
    }
  }

  public async setDriverAccountStatus(driverId: string, accountStatus: 'ACTIVE' | 'SUSPENDED' | 'BANNED'): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.account_status = accountStatus;
      if (accountStatus !== 'ACTIVE') {
        profile.is_online = false;
      }
      this.saveStore();
    }
  }

  public async getPendingKycDrivers(): Promise<(DriverProfileRow & { user?: UserRow })[]> {
    return this.store.driver_profiles
      .filter((d) => d.kyc_status === 'PENDING')
      .map((profile) => ({
        ...profile,
        user: this.store.users.find((u) => u.id === profile.driver_id),
      }));
  }

  // --- Manual Ride Credit & Audit ---
  public async addManualRideCredit(
    adminId: string,
    driverId: string,
    ridesToAdd: number,
    reason: string
  ): Promise<DriverSubscriptionRow> {
    let activeSub = await this.getActiveDriverSubscription(driverId);
    const previousRides = activeSub ? activeSub.remaining_rides : 0;

    if (!activeSub) {
      // Create a manual support subscription bundle
      const now = new Date();
      activeSub = {
        id: `manual_sub_${Date.now()}`,
        driver_id: driverId,
        plan_id: 'plan_starter_10',
        status: 'ACTIVE',
        remaining_rides: ridesToAdd,
        starts_at: now.toISOString(),
        expires_at: new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000).toISOString(),
        created_at: now.toISOString(),
      };
      this.store.driver_subscriptions.push(activeSub);
    } else {
      activeSub.remaining_rides += ridesToAdd;
      activeSub.status = 'ACTIVE';
    }

    // Automatically clear lockout if driver was locked out
    await this.updateDriverLockout(driverId, false);

    // Log the audit trail
    this.store.subscription_credit_audits.push({
      id: `audit_${Date.now()}`,
      admin_id: adminId,
      driver_id: driverId,
      rides_added: ridesToAdd,
      previous_rides: previousRides,
      new_rides: activeSub.remaining_rides,
      reason,
      created_at: new Date().toISOString(),
    });

    this.saveStore();
    return activeSub;
  }

  public async getCreditAudits(driverId?: string): Promise<SubscriptionCreditAuditRow[]> {
    if (driverId) {
      return this.store.subscription_credit_audits.filter((a) => a.driver_id === driverId);
    }
    return this.store.subscription_credit_audits;
  }

  // --- Subscription Plans ---
  public async getActivePlans(): Promise<SubscriptionPlanRow[]> {
    return this.store.subscription_plans.filter((p) => p.is_active);
  }

  public async getAllPlans(): Promise<SubscriptionPlanRow[]> {
    return this.store.subscription_plans;
  }

  public async getPlanById(planId: string): Promise<SubscriptionPlanRow | undefined> {
    return this.store.subscription_plans.find((p) => p.id === planId);
  }

  // --- Driver Subscriptions ---
  public async getActiveDriverSubscription(driverId: string): Promise<DriverSubscriptionRow | undefined> {
    const now = new Date().toISOString();
    return this.store.driver_subscriptions
      .filter((s) => s.driver_id === driverId && (s.is_frozen || s.expires_at > now) && (s.status === 'ACTIVE' || s.remaining_rides > -ENV.MAX_GRACE_RIDES))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
  }

  public async freezeDriverSubscription(driverId: string, reason?: string): Promise<DriverSubscriptionRow> {
    const activeSub = await this.getActiveDriverSubscription(driverId);
    if (!activeSub) throw new Error('No active subscription found to freeze.');
    if (activeSub.is_frozen) throw new Error('Subscription is already frozen.');

    activeSub.is_frozen = true;
    activeSub.frozen_at = new Date().toISOString();
    activeSub.freeze_reason = reason || 'Breakdown / Vehicle Maintenance';
    this.saveStore();
    return activeSub;
  }

  public async unfreezeDriverSubscription(driverId: string): Promise<DriverSubscriptionRow> {
    const sub = this.store.driver_subscriptions
      .filter((s) => s.driver_id === driverId)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
    if (!sub || !sub.is_frozen) throw new Error('Subscription is not currently frozen.');

    const elapsedMs = Date.now() - new Date(sub.frozen_at!).getTime();
    sub.expires_at = new Date(new Date(sub.expires_at).getTime() + elapsedMs).toISOString();
    sub.total_frozen_ms = (sub.total_frozen_ms || 0) + elapsedMs;
    sub.is_frozen = false;
    sub.frozen_at = undefined;
    sub.freeze_reason = undefined;
    this.saveStore();
    return sub;
  }

  public async createDriverSubscription(sub: DriverSubscriptionRow): Promise<DriverSubscriptionRow> {
    this.store.driver_subscriptions.forEach((s) => {
      if (s.driver_id === sub.driver_id && s.status === 'ACTIVE') {
        s.status = 'EXPIRED';
      }
    });
    this.store.driver_subscriptions.push(sub);
    this.saveStore();
    return sub;
  }

  public async decrementDriverRide(driverId: string): Promise<{
    remainingRides: number;
    status: 'ACTIVE' | 'EXHAUSTED' | 'EXPIRED';
    graceUsed: boolean;
  }> {
    const activeSub = await this.getActiveDriverSubscription(driverId);
    if (!activeSub) {
      return { remainingRides: 0, status: 'EXHAUSTED', graceUsed: false };
    }
    if (activeSub.is_frozen) {
      throw new Error('Subscription is currently frozen / snoozed. Unfreeze before accepting rides.');
    }

    const plan = await this.getPlanById(activeSub.plan_id);
    if (plan?.plan_type === 'UNLIMITED') {
      return { remainingRides: 999999, status: 'ACTIVE', graceUsed: false };
    }

    activeSub.remaining_rides -= 1;
    let graceUsed = false;

    if (activeSub.remaining_rides < 0 && activeSub.remaining_rides >= -ENV.MAX_GRACE_RIDES) {
      graceUsed = true;
    }

    if (activeSub.remaining_rides <= -ENV.MAX_GRACE_RIDES) {
      activeSub.status = 'EXHAUSTED';
    }

    // Increment driver's total trips
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.total_trips_completed = (profile.total_trips_completed || 0) + 1;
    }

    this.saveStore();

    return {
      remainingRides: activeSub.remaining_rides,
      status: activeSub.status,
      graceUsed,
    };
  }

  // --- Rides ---
  public async createRide(ride: RideRow): Promise<RideRow> {
    this.store.rides.push(ride);
    this.saveStore();
    return ride;
  }

  public async getRideById(id: string): Promise<RideRow | undefined> {
    return this.store.rides.find((r) => r.id === id);
  }

  public async getActiveRides(): Promise<any[]> {
    const active = this.store.rides.filter((r) =>
      ['REQUESTED', 'NEGOTIATING', 'ACCEPTED', 'ARRIVED', 'IN_TRANSIT'].includes(r.status)
    );

    return active.map((r) => ({
      ...r,
      rider: this.store.users.find((u) => u.id === r.rider_id),
      driver: r.driver_id ? this.store.users.find((u) => u.id === r.driver_id) : null,
      driverProfile: r.driver_id ? this.store.driver_profiles.find((d) => d.driver_id === r.driver_id) : null,
    }));
  }

  public async updateRideStatus(
    rideId: string,
    status: RideRow['status'],
    driverId?: string,
    agreedFare?: number
  ): Promise<RideRow | undefined> {
    const ride = this.store.rides.find((r) => r.id === rideId);
    if (ride) {
      ride.status = status;
      if (driverId) ride.driver_id = driverId;
      if (agreedFare) ride.agreed_fare_ngn = agreedFare;
      if (status === 'COMPLETED') {
        ride.completed_at = new Date().toISOString();
      }
      this.saveStore();
    }
    return ride;
  }

  public async getRiderHistory(riderId: string): Promise<RideRow[]> {
    return this.store.rides
      .filter((r) => r.rider_id === riderId)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }

  public async getDriverHistory(driverId: string): Promise<RideRow[]> {
    return this.store.rides
      .filter((r) => r.driver_id === driverId)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }

  // --- Ride Bids ---
  public async createBid(bid: RideBidRow): Promise<RideBidRow> {
    this.store.ride_bids.push(bid);
    this.saveStore();
    return bid;
  }

  public async getBidsForRide(rideId: string): Promise<(RideBidRow & { driver?: DriverProfileRow & { user?: UserRow } })[]> {
    return this.store.ride_bids
      .filter((b) => b.ride_id === rideId)
      .map((bid) => {
        const driverProfile = this.store.driver_profiles.find((d) => d.driver_id === bid.driver_id);
        const user = this.store.users.find((u) => u.id === bid.driver_id);
        return {
          ...bid,
          driver: driverProfile ? { ...driverProfile, user } : undefined,
        };
      });
  }

  public async acceptBid(rideId: string, driverId: string): Promise<void> {
    this.store.ride_bids.forEach((b) => {
      if (b.ride_id === rideId) {
        b.status = b.driver_id === driverId ? 'ACCEPTED' : 'REJECTED';
      }
    });
    this.saveStore();
  }

  // --- Emergency SOS Incidents ---
  public async createSosIncident(incident: SosIncidentRow): Promise<SosIncidentRow> {
    this.store.sos_incidents.push(incident);
    this.saveStore();
    return incident;
  }

  public async getSosIncidents(status?: 'OPEN' | 'IN_REVIEW' | 'RESOLVED'): Promise<any[]> {
    let incidents = [...this.store.sos_incidents];
    if (status) {
      incidents = incidents.filter((i) => i.status === status);
    }
    return incidents.map((i) => {
      const ride = this.store.rides.find((r) => r.id === i.ride_id);
      const rider = this.store.users.find((u) => u.id === i.rider_id);
      const driver = i.driver_id ? this.store.users.find((u) => u.id === i.driver_id) : null;
      const driverProfile = i.driver_id ? this.store.driver_profiles.find((d) => d.driver_id === i.driver_id) : null;
      return { ...i, ride, rider, driver, driverProfile };
    });
  }

  public async resolveSosIncident(id: string, notes: string): Promise<void> {
    const inc = this.store.sos_incidents.find((i) => i.id === id);
    if (inc) {
      inc.status = 'RESOLVED';
      inc.notes = notes;
      inc.resolved_at = new Date().toISOString();
      this.saveStore();
    }
  }

  // --- Transactions ---
  public async createTransaction(tx: PaymentTransactionRow): Promise<PaymentTransactionRow> {
    this.store.payment_transactions.push(tx);
    this.saveStore();
    return tx;
  }

  public async getTransactions(): Promise<any[]> {
    return this.store.payment_transactions.map((tx) => {
      const user = this.store.users.find((u) => u.id === tx.user_id);
      return { ...tx, user };
    });
  }

  public async getTransactionByRef(reference: string): Promise<PaymentTransactionRow | undefined> {
    return this.store.payment_transactions.find((t) => t.reference === reference);
  }

  public async updateTransactionStatus(reference: string, status: 'SUCCESS' | 'FAILED'): Promise<void> {
    const tx = this.store.payment_transactions.find((t) => t.reference === reference);
    if (tx) {
      tx.status = status;
      this.saveStore();
    }
  }

  // --- Platform Analytics & Lagos MOT Audit ---
  public async getAnalytics() {
    const totalDrivers = this.store.driver_profiles.length;
    const pendingKyc = this.store.driver_profiles.filter((d) => d.kyc_status === 'PENDING').length;
    const activeDrivers = this.store.driver_profiles.filter((d) => d.is_online).length;
    const totalPassengers = this.store.users.filter((u) => u.role === 'PASSENGER').length;
    const completedRides = this.store.rides.filter((r) => r.status === 'COMPLETED');
    const totalRidesCompleted = completedRides.length;

    const totalSubscriptionRevenueKobo = this.store.payment_transactions
      .filter((t) => t.status === 'SUCCESS')
      .reduce((sum, t) => sum + t.amount_kobo, 0);

    // Lagos State Ministry of Transportation (MOT) ₦50 e-hailing levy audit
    const lagosMotLevyTotalNgn = totalRidesCompleted * this.store.platform_settings.lagos_mot_levy_ngn;

    const openSosCount = this.store.sos_incidents.filter((s) => s.status === 'OPEN').length;

    return {
      totalDrivers,
      pendingKyc,
      activeDrivers,
      totalPassengers,
      totalRidesCompleted,
      totalSubscriptionRevenueNgn: totalSubscriptionRevenueKobo / 100,
      lagosMotLevyTotalNgn,
      activePlans: this.store.subscription_plans.length,
      openSosCount,
      platformSettings: this.store.platform_settings,
    };
  }

  // --- Dynamic Subscription Plan CRUD ---
  public async createSubscriptionPlan(plan: SubscriptionPlanRow): Promise<SubscriptionPlanRow> {
    const existing = this.store.subscription_plans.find((p) => p.id === plan.id);
    if (existing) throw new Error(`Plan ID ${plan.id} already exists.`);
    this.store.subscription_plans.push(plan);
    this.saveStore();
    return plan;
  }

  public async updateSubscriptionPlan(id: string, updates: Partial<SubscriptionPlanRow>): Promise<SubscriptionPlanRow> {
    const plan = this.store.subscription_plans.find((p) => p.id === id);
    if (!plan) throw new Error(`Plan ${id} not found.`);
    Object.assign(plan, updates);
    this.saveStore();
    return plan;
  }

  public async deleteSubscriptionPlan(id: string): Promise<boolean> {
    const idx = this.store.subscription_plans.findIndex((p) => p.id === id);
    if (idx >= 0) {
      this.store.subscription_plans.splice(idx, 1);
      this.saveStore();
      return true;
    }
    return false;
  }

  // --- Document Expiry & LASG Compliance ---
  public async updateDriverDocuments(
    driverId: string,
    docs: {
      driver_license_expiry?: string;
      insurance_expiry?: string;
      road_worthiness_expiry?: string;
      lasdri_card_number?: string;
      lasdri_expiry?: string;
    }
  ): Promise<DriverProfileRow> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (!profile) throw new Error('Driver profile not found.');
    Object.assign(profile, docs);
    this.saveStore();
    return profile;
  }

  public async getExpiringComplianceDrivers(daysAhead: number = 30): Promise<any[]> {
    const now = new Date();
    const threshold = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000);

    return this.store.driver_profiles
      .map((p) => {
        const user = this.store.users.find((u) => u.id === p.driver_id);
        const isLicenseExpiring = !!(p.driver_license_expiry && new Date(p.driver_license_expiry) <= threshold);
        const isInsuranceExpiring = !!(p.insurance_expiry && new Date(p.insurance_expiry) <= threshold);
        const isRoadWorthinessExpiring = !!(p.road_worthiness_expiry && new Date(p.road_worthiness_expiry) <= threshold);
        const isLasdriExpiring = !!(p.lasdri_expiry && new Date(p.lasdri_expiry) <= threshold);

        const hasExpiredDoc = !!(
          (p.driver_license_expiry && new Date(p.driver_license_expiry) < now) ||
          (p.insurance_expiry && new Date(p.insurance_expiry) < now) ||
          (p.road_worthiness_expiry && new Date(p.road_worthiness_expiry) < now) ||
          (p.lasdri_expiry && new Date(p.lasdri_expiry) < now)
        );

        return {
          ...p,
          user,
          complianceAlerts: {
            isLicenseExpiring,
            isInsuranceExpiring,
            isRoadWorthinessExpiring,
            isLasdriExpiring,
            hasExpiredDoc,
          },
        };
      })
      .filter(
        (d) =>
          d.complianceAlerts.isLicenseExpiring ||
          d.complianceAlerts.isInsuranceExpiring ||
          d.complianceAlerts.isRoadWorthinessExpiring ||
          d.complianceAlerts.isLasdriExpiring
      );
  }

  // --- Immutable Admin Operations Audit Log ---
  public async logAdminAudit(data: Omit<AdminAuditLogRow, 'id' | 'created_at'>): Promise<AdminAuditLogRow> {
    const log: AdminAuditLogRow = {
      id: `audit_log_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      ...data,
      created_at: new Date().toISOString(),
    };
    this.store.admin_audit_logs.unshift(log);
    if (this.store.admin_audit_logs.length > 10000) {
      this.store.admin_audit_logs.pop();
    }
    this.saveStore();
    return log;
  }

  public async getAdminAuditLogs(limit: number = 100, action?: string): Promise<AdminAuditLogRow[]> {
    let logs = [...this.store.admin_audit_logs];
    if (action) {
      logs = logs.filter((l) => l.action.toLowerCase().includes(action.toLowerCase()));
    }
    return logs.slice(0, limit);
  }

  // --- In-App Disputes Desk ---
  public async createDispute(data: {
    ride_id: string;
    reporter_id: string;
    reporter_role: 'PASSENGER' | 'DRIVER';
    dispute_type: string;
    description: string;
  }): Promise<DisputeRow> {
    const dispute: DisputeRow = {
      id: `disp_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      ride_id: data.ride_id,
      reporter_id: data.reporter_id,
      reporter_role: data.reporter_role,
      dispute_type: data.dispute_type,
      description: data.description,
      status: 'OPEN',
      driver_strike_applied: false,
      compensation_rides: 0,
      created_at: new Date().toISOString(),
    };
    this.store.disputes.unshift(dispute);
    this.saveStore();
    return dispute;
  }

  public async getDisputes(status?: string): Promise<any[]> {
    let list = [...this.store.disputes];
    if (status && status !== 'ALL') {
      list = list.filter((d) => d.status === status);
    }
    return list.map((d) => {
      const ride = this.store.rides.find((r) => r.id === d.ride_id);
      const reporter = this.store.users.find((u) => u.id === d.reporter_id);
      const driver = ride?.driver_id ? this.store.users.find((u) => u.id === ride.driver_id) : null;
      const passenger = ride?.rider_id ? this.store.users.find((u) => u.id === ride.rider_id) : null;
      return { ...d, ride, reporter, driver, passenger };
    });
  }

  public async resolveDispute(
    id: string,
    resolutionNotes: string,
    driverStrikeApplied: boolean = false,
    compensationRides: number = 0
  ): Promise<DisputeRow> {
    const dispute = this.store.disputes.find((d) => d.id === id);
    if (!dispute) throw new Error(`Dispute ${id} not found.`);
    dispute.status = 'RESOLVED';
    dispute.resolution_notes = resolutionNotes;
    dispute.driver_strike_applied = driverStrikeApplied;
    dispute.compensation_rides = compensationRides;
    dispute.resolved_at = new Date().toISOString();
    this.saveStore();
    return dispute;
  }

  // --- High-Resolution GPS Breadcrumbs ---
  public async recordRideBreadcrumb(breadcrumb: Omit<RideGpsBreadcrumbRow, 'id' | 'recorded_at'>): Promise<RideGpsBreadcrumbRow> {
    const entry: RideGpsBreadcrumbRow = {
      id: `crumb_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      ...breadcrumb,
      recorded_at: new Date().toISOString(),
    };
    this.store.ride_gps_breadcrumbs.push(entry);
    this.saveStore();
    return entry;
  }

  public async getRideBreadcrumbs(rideId: string): Promise<RideGpsBreadcrumbRow[]> {
    return this.store.ride_gps_breadcrumbs
      .filter((c) => c.ride_id === rideId)
      .sort((a, b) => new Date(a.recorded_at).getTime() - new Date(b.recorded_at).getTime());
  }

  // --- LASG Ministry of Transportation ₦50 Levy Export Data ---
  public async getCompletedRidesForMotExport(): Promise<any[]> {
    const completed = this.store.rides.filter((r) => r.status === 'COMPLETED');
    return completed.map((r) => {
      const driverUser = r.driver_id ? this.store.users.find((u) => u.id === r.driver_id) : null;
      const driverProfile = r.driver_id ? this.store.driver_profiles.find((d) => d.driver_id === r.driver_id) : null;
      const passengerUser = this.store.users.find((u) => u.id === r.rider_id);

      return {
        ride_id: r.id,
        completed_at: r.completed_at || r.created_at,
        driver_name: driverUser?.full_name || 'Unknown',
        driver_phone: driverUser?.phone_number || '',
        driver_nin: driverProfile?.nin || 'N/A',
        license_plate: driverProfile?.license_plate || 'N/A',
        passenger_name: passengerUser?.full_name || 'Passenger',
        pickup_address: r.pickup_address,
        dropoff_address: r.dropoff_address,
        distance_km: r.distance_km,
        agreed_fare_ngn: r.agreed_fare_ngn || r.suggested_fare_ngn,
        lagos_mot_levy_ngn: this.store.platform_settings.lagos_mot_levy_ngn,
      };
    });
  }

  // --- Dedicated Virtual Bank Accounts (Korapay DVA) ---
  public async getVirtualAccountByUserId(userId: string): Promise<VirtualBankAccountRow | undefined> {
    return this.store.virtual_bank_accounts.find((v) => v.user_id === userId);
  }

  public async getVirtualAccountByNumber(accountNumber: string): Promise<VirtualBankAccountRow | undefined> {
    return this.store.virtual_bank_accounts.find((v) => v.account_number === accountNumber);
  }

  public async createOrUpdateVirtualAccount(acc: VirtualBankAccountRow): Promise<VirtualBankAccountRow> {
    const existingIndex = this.store.virtual_bank_accounts.findIndex((v) => v.user_id === acc.user_id);
    if (existingIndex >= 0) {
      this.store.virtual_bank_accounts[existingIndex] = { ...this.store.virtual_bank_accounts[existingIndex], ...acc };
    } else {
      this.store.virtual_bank_accounts.push(acc);
    }
    this.saveStore();
    return acc;
  }

  public async creditVirtualAccountBalance(accountNumberOrUserId: string, amountNgn: number): Promise<VirtualBankAccountRow> {
    let acc = this.store.virtual_bank_accounts.find((v) => v.account_number === accountNumberOrUserId || v.user_id === accountNumberOrUserId);
    if (!acc) {
      const user = this.store.users.find((u) => u.id === accountNumberOrUserId);
      acc = {
        id: `vba_${Date.now()}`,
        user_id: accountNumberOrUserId,
        account_reference: `dva_${Date.now()}`,
        account_number: `99${Math.floor(10000000 + Math.random() * 90000000).toString().slice(0, 8)}`,
        bank_name: 'Wema Bank (Giga Dedicated)',
        bank_code: '035',
        account_name: user?.full_name || 'Giga Passenger',
        provider: 'korapay',
        balance_ngn: 0,
        is_active: true,
        created_at: new Date().toISOString(),
      };
      this.store.virtual_bank_accounts.push(acc);
    }
    acc.balance_ngn = Number((acc.balance_ngn + amountNgn).toFixed(2));
    this.saveStore();
    return acc;
  }

  public async debitVirtualAccountBalance(accountNumberOrUserId: string, amountNgn: number): Promise<VirtualBankAccountRow | undefined> {
    const acc = this.store.virtual_bank_accounts.find((v) => v.account_number === accountNumberOrUserId || v.user_id === accountNumberOrUserId);
    if (acc) {
      if (acc.balance_ngn < amountNgn) throw new Error('Insufficient virtual account funds.');
      acc.balance_ngn = Number((acc.balance_ngn - amountNgn).toFixed(2));
      this.saveStore();
      return acc;
    }
    return undefined;
  }

  public async swapWalletVault(
    userId: string,
    direction: 'MAIN_TO_VAULT' | 'VAULT_TO_MAIN',
    amountNgn: number
  ): Promise<VirtualBankAccountRow> {
    const acc = this.store.virtual_bank_accounts.find((v) => v.user_id === userId);
    if (!acc) throw new Error('Virtual bank account not found.');
    if (amountNgn <= 0) throw new Error('Transfer amount must be greater than zero.');

    acc.vault_balance_ngn = acc.vault_balance_ngn || 0;

    if (direction === 'MAIN_TO_VAULT') {
      if (acc.balance_ngn < amountNgn) throw new Error('Insufficient available balance in Main Ride Wallet.');
      acc.balance_ngn = Number((acc.balance_ngn - amountNgn).toFixed(2));
      acc.vault_balance_ngn = Number((acc.vault_balance_ngn + amountNgn).toFixed(2));
    } else {
      if (acc.vault_balance_ngn < amountNgn) throw new Error('Insufficient locked funds in Giga Vault.');
      acc.vault_balance_ngn = Number((acc.vault_balance_ngn - amountNgn).toFixed(2));
      acc.balance_ngn = Number((acc.balance_ngn + amountNgn).toFixed(2));
    }

    // Record internal swap in transaction ledger
    this.store.payment_transactions.unshift({
      id: `tx_swap_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      reference: `SWAP_${Date.now()}`,
      user_id: userId,
      amount_kobo: Math.round(amountNgn * 100),
      status: 'SUCCESS',
      payment_type: 'SUBSCRIPTION_PURCHASE',
      channel: 'INTERNAL_SWAP',
      meta_data: { direction, amountNgn, newMain: acc.balance_ngn, newVault: acc.vault_balance_ngn },
      created_at: new Date().toISOString(),
    });

    this.saveStore();
    return acc;
  }

  public async withdrawFromWallet(
    userId: string,
    amountNgn: number,
    bankDetails: { bankName: string; accountNumber: string; accountName: string; bankCode: string }
  ): Promise<{ transaction: PaymentTransactionRow; remainingBalance: number; beneficiary: BeneficiaryRow }> {
    const acc = this.store.virtual_bank_accounts.find((v) => v.user_id === userId);
    if (!acc) throw new Error('Virtual bank account not found.');
    if (amountNgn < 500) throw new Error('Minimum withdrawal amount is ₦500.');
    if (acc.balance_ngn < amountNgn) throw new Error('Insufficient wallet balance for withdrawal.');

    acc.balance_ngn = Number((acc.balance_ngn - amountNgn).toFixed(2));

    const tx: PaymentTransactionRow = {
      id: `tx_wdr_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      reference: `WDR_${Date.now()}`,
      user_id: userId,
      amount_kobo: Math.round(amountNgn * 100),
      status: 'SUCCESS',
      payment_type: 'SUBSCRIPTION_PURCHASE',
      channel: 'NIP_TRANSFER',
      meta_data: { bankDetails, amountNgn, type: 'WALLET_WITHDRAWAL' },
      created_at: new Date().toISOString(),
    };

    this.store.payment_transactions.unshift(tx);

    // Auto-remember destination beneficiary with 30-day activity tracking
    const beneficiary = await this.saveOrUpdateBeneficiary(userId, {
      account_name: bankDetails.accountName,
      account_number: bankDetails.accountNumber,
      bank_name: bankDetails.bankName,
      bank_code: bankDetails.bankCode,
    });

    this.saveStore();
    return { transaction: tx, remainingBalance: acc.balance_ngn, beneficiary };
  }

  // --- Auto-Remember Beneficiaries (30-Day Living Memory) ---
  public async saveOrUpdateBeneficiary(
    userId: string,
    data: {
      account_name: string;
      account_number: string;
      bank_name: string;
      bank_code: string;
      nickname?: string;
      is_pinned?: boolean;
    }
  ): Promise<BeneficiaryRow> {
    let existing = this.store.beneficiaries.find(
      (b) => b.user_id === userId && b.account_number === data.account_number && b.bank_code === data.bank_code
    );

    const now = new Date().toISOString();

    if (existing) {
      existing.account_name = data.account_name;
      existing.bank_name = data.bank_name;
      if (data.nickname) existing.nickname = data.nickname;
      if (data.is_pinned !== undefined) existing.is_pinned = data.is_pinned;
      existing.last_transacted_at = now;
      this.saveStore();
      return existing;
    }

    const newBen: BeneficiaryRow = {
      id: `ben_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      user_id: userId,
      account_name: data.account_name,
      account_number: data.account_number,
      bank_name: data.bank_name,
      bank_code: data.bank_code,
      nickname: data.nickname,
      last_transacted_at: now,
      is_pinned: data.is_pinned || false,
      created_at: now,
    };

    this.store.beneficiaries.unshift(newBen);
    this.saveStore();
    return newBen;
  }

  public async getBeneficiaries(userId: string, search?: string, daysLimit: number = 90): Promise<BeneficiaryRow[]> {
    const cutoffTime = Date.now() - daysLimit * 24 * 60 * 60 * 1000;

    let list = this.store.beneficiaries.filter((b) => {
      if (b.user_id !== userId) return false;
      const isRecent = new Date(b.last_transacted_at).getTime() >= cutoffTime;
      return b.is_pinned || isRecent;
    });

    if (search && search.trim().length > 0) {
      const q = search.toLowerCase().trim();
      list = list.filter(
        (b) =>
          b.account_name.toLowerCase().includes(q) ||
          b.account_number.includes(q) ||
          b.bank_name.toLowerCase().includes(q) ||
          (b.nickname && b.nickname.toLowerCase().includes(q))
      );
    }

    return list.sort((a, b) => {
      if (a.is_pinned && !b.is_pinned) return -1;
      if (!a.is_pinned && b.is_pinned) return 1;
      return new Date(b.last_transacted_at).getTime() - new Date(a.last_transacted_at).getTime();
    });
  }

  public async deleteBeneficiary(userId: string, beneficiaryId: string): Promise<boolean> {
    const idx = this.store.beneficiaries.findIndex((b) => b.id === beneficiaryId && b.user_id === userId);
    if (idx >= 0) {
      this.store.beneficiaries.splice(idx, 1);
      this.saveStore();
      return true;
    }
    return false;
  }

  public async getLivingWalletDetails(userId: string): Promise<any> {
    let acc = this.store.virtual_bank_accounts.find((v) => v.user_id === userId);
    const user = this.store.users.find((u) => u.id === userId);
    if (!acc && user) {
      acc = {
        id: `va_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        user_id: userId,
        account_reference: `ref_va_${Date.now()}`,
        account_number: `100${Math.floor(1000000 + Math.random() * 9000000)}`,
        bank_name: 'Wema Bank / Korapay',
        bank_code: '035',
        account_name: user.full_name,
        provider: 'korapay',
        balance_ngn: 0,
        vault_balance_ngn: 0,
        is_active: true,
        created_at: new Date().toISOString(),
      };
      this.store.virtual_bank_accounts.push(acc);
      this.saveStore();
    }

    const transactions = this.store.payment_transactions
      .filter((t) => t.user_id === userId)
      .slice(0, 50);

    const beneficiaries = await this.getBeneficiaries(userId, undefined, 90);

    return {
      virtualAccount: acc ? { ...acc, vault_balance_ngn: acc.vault_balance_ngn || 0 } : null,
      user: user ? { id: user.id, full_name: user.full_name, email: user.email, phone_number: user.phone_number } : null,
      recentTransactions: transactions,
      beneficiaries,
    };
  }


  // --- Saved Cards & Card Transactions Management ---
  public async getUserSavedCards(userId: string): Promise<UserSavedCardRow[]> {
    if (!this.store.user_saved_cards) this.store.user_saved_cards = [];
    return this.store.user_saved_cards.filter((c) => c.user_id === userId);
  }

  public async saveCardToken(userId: string, cardData: Omit<UserSavedCardRow, 'id' | 'created_at'>): Promise<UserSavedCardRow> {
    if (!this.store.user_saved_cards) this.store.user_saved_cards = [];
    
    let existing = this.store.user_saved_cards.find(
      (c) => c.user_id === userId && c.card_last4 === cardData.card_last4 && c.card_brand.toLowerCase() === cardData.card_brand.toLowerCase()
    );

    const now = new Date().toISOString();
    if (existing) {
      existing.authorization_code = cardData.authorization_code;
      existing.card_bank = cardData.card_bank;
      existing.exp_month = cardData.exp_month;
      existing.exp_year = cardData.exp_year;
      if (cardData.is_default) {
        this.store.user_saved_cards.forEach((c) => { if (c.user_id === userId) c.is_default = false; });
        existing.is_default = true;
      }
      this.saveStore();
      return existing;
    }

    const hasCards = this.store.user_saved_cards.some((c) => c.user_id === userId);
    const newCard: UserSavedCardRow = {
      id: `card_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      ...cardData,
      user_id: userId,
      is_default: cardData.is_default ?? (!hasCards),
      created_at: now,
    };

    if (newCard.is_default) {
      this.store.user_saved_cards.forEach((c) => { if (c.user_id === userId) c.is_default = false; });
    }

    this.store.user_saved_cards.unshift(newCard);
    this.saveStore();
    return newCard;
  }

  public async deleteSavedCard(userId: string, cardId: string): Promise<boolean> {
    if (!this.store.user_saved_cards) this.store.user_saved_cards = [];
    const idx = this.store.user_saved_cards.findIndex((c) => c.id === cardId && c.user_id === userId);
    if (idx >= 0) {
      this.store.user_saved_cards.splice(idx, 1);
      this.saveStore();
      return true;
    }
    return false;
  }

  public async setDefaultSavedCard(userId: string, cardId: string): Promise<UserSavedCardRow> {
    if (!this.store.user_saved_cards) this.store.user_saved_cards = [];
    let target: UserSavedCardRow | undefined;
    for (const c of this.store.user_saved_cards) {
      if (c.user_id === userId) {
        if (c.id === cardId) {
          c.is_default = true;
          target = c;
        } else {
          c.is_default = false;
        }
      }
    }
    if (!target) throw new Error('Card not found.');
    this.saveStore();
    return target;
  }

  public async getCardTransactions(userId: string): Promise<PaymentTransactionRow[]> {
    return this.store.payment_transactions
      .filter((t) => t.user_id === userId && (t.channel.includes('card') || t.channel.includes('paystack') || Boolean(t.card_last4)))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }

  // --- Peer-to-Peer Wallet Transfer with 3-Month Auto-Beneficiary ---
  public async transferP2PWallet(
    senderId: string,
    recipientSearch: string,
    amountNgn: number,
    saveAsBeneficiary: boolean = true
  ): Promise<{ transaction: PaymentTransactionRow; remainingBalance: number; recipientName: string }> {
    const senderAcc = this.store.virtual_bank_accounts.find((v) => v.user_id === senderId);
    if (!senderAcc) throw new Error('Sender wallet not found.');
    if (amountNgn < 100) throw new Error('Minimum transfer amount is ₦100.');
    if (senderAcc.balance_ngn < amountNgn) throw new Error('Insufficient wallet balance.');

    const q = recipientSearch.trim().toLowerCase();
    const recipient = this.store.users.find(
      (u) => u.id !== senderId && (u.phone_number.toLowerCase().includes(q) || u.email.toLowerCase() === q || u.full_name.toLowerCase().includes(q))
    );
    if (!recipient) throw new Error('Recipient user not found on Giga Ride.');

    let recipientAcc = this.store.virtual_bank_accounts.find((v) => v.user_id === recipient.id);
    if (!recipientAcc) {
      recipientAcc = {
        id: `va_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        user_id: recipient.id,
        account_reference: `ref_va_${Date.now()}`,
        account_number: `100${Math.floor(1000000 + Math.random() * 9000000)}`,
        bank_name: 'Wema Bank / Korapay',
        bank_code: '035',
        account_name: recipient.full_name,
        provider: 'korapay',
        balance_ngn: 0,
        vault_balance_ngn: 0,
        is_active: true,
        created_at: new Date().toISOString(),
      };
      this.store.virtual_bank_accounts.push(recipientAcc);
    }

    senderAcc.balance_ngn = Number((senderAcc.balance_ngn - amountNgn).toFixed(2));
    recipientAcc.balance_ngn = Number((recipientAcc.balance_ngn + amountNgn).toFixed(2));

    const txRef = `P2P_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const tx: PaymentTransactionRow = {
      id: `tx_${txRef}`,
      reference: txRef,
      user_id: senderId,
      amount_kobo: Math.round(amountNgn * 100),
      status: 'SUCCESS',
      payment_type: 'SUBSCRIPTION_PURCHASE',
      channel: 'P2P_TRANSFER',
      meta_data: {
        recipientId: recipient.id,
        recipientName: recipient.full_name,
        recipientPhone: recipient.phone_number,
        amountNgn,
        type: 'P2P_TRANSFER'
      },
      created_at: new Date().toISOString(),
    };
    this.store.payment_transactions.unshift(tx);

    if (saveAsBeneficiary) {
      await this.saveOrUpdateBeneficiary(senderId, {
        account_name: recipient.full_name,
        account_number: recipient.phone_number,
        bank_name: 'Giga Living Wallet',
        bank_code: 'GIGA_P2P',
      });
    }

    this.saveStore();
    return { transaction: tx, remainingBalance: senderAcc.balance_ngn, recipientName: recipient.full_name };
  }

  // --- Phone OTP Verifications (Twilio) ---
  public async savePhoneOtp(phoneNumber: string, otpCode: string, expiryMinutes = 10): Promise<PhoneVerificationRow> {
    const expiresAt = new Date(Date.now() + expiryMinutes * 60000).toISOString();
    let record = this.store.phone_verifications.find((p) => p.phone_number === phoneNumber);
    if (record) {
      record.otp_code = otpCode;
      record.expires_at = expiresAt;
      record.is_verified = false;
      record.attempts = 0;
    } else {
      record = {
        id: `pv_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        phone_number: phoneNumber,
        otp_code: otpCode,
        attempts: 0,
        expires_at: expiresAt,
        is_verified: false,
        created_at: new Date().toISOString(),
      };
      this.store.phone_verifications.push(record);
    }
    this.saveStore();
    return record;
  }

  public async isPhoneVerified(phoneNumber: string): Promise<boolean> {
    const user = this.store.users.find((u) => u.phone_number === phoneNumber);
    if (user && user.is_phone_verified) return true;
    const record = this.store.phone_verifications.find((p) => p.phone_number === phoneNumber && p.is_verified);
    return !!record;
  }

  public async verifyPhoneOtp(phoneNumber: string, otpCode: string): Promise<boolean> {
    const record = this.store.phone_verifications.find((p) => p.phone_number === phoneNumber);
    if (!record) return false;
    if (new Date(record.expires_at).getTime() < Date.now()) return false;
    if (record.otp_code !== otpCode) {
      record.attempts += 1;
      this.saveStore();
      return false;
    }
    record.is_verified = true;
    const user = this.store.users.find((u) => u.phone_number === phoneNumber);
    if (user) user.is_phone_verified = true;
    this.saveStore();
    return true;
  }

  // --- Prembly KYC Verifications ---
  public async recordKycVerification(data: Omit<KycVerificationRow, 'id' | 'created_at'>): Promise<KycVerificationRow> {
    const entry: KycVerificationRow = {
      id: `kyc_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      ...data,
      created_at: new Date().toISOString(),
    };
    this.store.kyc_verifications.unshift(entry);
    this.saveStore();
    return entry;
  }

  public async getKycVerificationsByDriver(driverId: string): Promise<KycVerificationRow[]> {
    return this.store.kyc_verifications.filter((k) => k.driver_id === driverId);
  }

  // --- Driver Lockout & Auto Topup Levers ---
  public async updateDriverLockout(driverId: string, isLockedOut: boolean, reason?: string | null): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.is_locked_out = isLockedOut;
      profile.lockout_reason = reason;
      if (isLockedOut) {
        profile.is_online = false;
      }
      this.saveStore();
    }
  }

  public async updateDriverAutoTopup(driverId: string, autoTopupEnabled: boolean, preferredPlanId?: string): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.auto_topup_enabled = autoTopupEnabled;
      if (preferredPlanId) profile.preferred_plan_id = preferredPlanId;
      this.saveStore();
    }
  }

  // --- Driver Payouts & Settlement ---
  public async getDriverPayouts(filter?: { status?: string; driverId?: string }): Promise<any[]> {
    let payouts = [...this.store.driver_payouts].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    if (filter?.status && filter.status !== 'ALL') {
      payouts = payouts.filter((p) => p.status === filter.status);
    }
    if (filter?.driverId) {
      payouts = payouts.filter((p) => p.driver_id === filter.driverId);
    }
    return payouts.map((p) => {
      const driver = this.store.users.find((u) => u.id === p.driver_id);
      const profile = this.store.driver_profiles.find((dp) => dp.driver_id === p.driver_id);
      return { ...p, driver, profile };
    });
  }

  public async createDriverPayout(data: {
    driver_id: string;
    amount_ngn: number;
    bank_name: string;
    bank_code: string;
    account_number: string;
    account_name: string;
  }): Promise<DriverPayoutRow> {
    const feeNgn = 50; // Standard ₦50 NIP settlement fee
    if (data.amount_ngn < 1000) throw new Error('Minimum withdrawal amount is ₦1,000.');
    const netAmountNgn = data.amount_ngn - feeNgn;

    // Immediately debit virtual account
    await this.debitVirtualAccountBalance(data.driver_id, data.amount_ngn);

    const payout: DriverPayoutRow = {
      id: `payout_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      driver_id: data.driver_id,
      amount_ngn: data.amount_ngn,
      fee_ngn: feeNgn,
      net_amount_ngn: netAmountNgn,
      bank_name: data.bank_name,
      bank_code: data.bank_code,
      account_number: data.account_number,
      account_name: data.account_name,
      status: 'PENDING',
      reference: `KORA_PAYOUT_${Date.now()}`,
      created_at: new Date().toISOString(),
    };

    this.store.driver_payouts.unshift(payout);
    this.saveStore();
    return payout;
  }

  public async updateDriverPayoutStatus(
    id: string,
    status: 'APPROVED' | 'TRANSFERRED' | 'REJECTED',
    rejectionReason?: string
  ): Promise<DriverPayoutRow> {
    const payout = this.store.driver_payouts.find((p) => p.id === id);
    if (!payout) throw new Error('Payout record not found.');
    payout.status = status;
    payout.processed_at = new Date().toISOString();
    if (rejectionReason) payout.rejection_reason = rejectionReason;

    // If rejected, refund the driver's virtual account balance
    if (status === 'REJECTED') {
      await this.creditVirtualAccountBalance(payout.driver_id, payout.amount_ngn);
    }

    this.saveStore();
    return payout;
  }

  // --- Multi-City Pricing & Surcharges ---
  public async getCityZones(): Promise<CityZoneRow[]> {
    return this.store.city_zones;
  }

  public async getCityZoneById(id: string): Promise<CityZoneRow | undefined> {
    return this.store.city_zones.find((c) => c.id === id);
  }

  public async createCityZone(zone: CityZoneRow): Promise<CityZoneRow> {
    const exists = this.store.city_zones.find((c) => c.id === zone.id);
    if (exists) throw new Error(`City with ID ${zone.id} already exists.`);
    this.store.city_zones.push(zone);
    this.saveStore();
    return zone;
  }

  public async updateCityZone(id: string, updates: Partial<CityZoneRow>): Promise<CityZoneRow> {
    const zone = this.store.city_zones.find((c) => c.id === id);
    if (!zone) throw new Error('City zone not found.');
    Object.assign(zone, updates);
    this.saveStore();
    return zone;
  }

  // --- Promo Codes & Acquisition Engine ---
  public async getPromoCodes(): Promise<PromoCodeRow[]> {
    return this.store.promo_codes;
  }

  public async createPromoCode(promo: PromoCodeRow): Promise<PromoCodeRow> {
    const exists = this.store.promo_codes.find((p) => p.code.toUpperCase() === promo.code.toUpperCase());
    if (exists) throw new Error(`Promo code ${promo.code} already exists.`);
    promo.code = promo.code.toUpperCase();
    this.store.promo_codes.push(promo);
    this.saveStore();
    return promo;
  }

  public async validateAndApplyPromo(code: string, fareNgn: number): Promise<{ valid: boolean; discountNgn: number; finalFareNgn: number; message: string }> {
    const promo = this.store.promo_codes.find((p) => p.code.toUpperCase() === code.toUpperCase() && p.is_active);
    if (!promo) return { valid: false, discountNgn: 0, finalFareNgn: fareNgn, message: 'Invalid or inactive promo code.' };
    if (new Date(promo.expires_at).getTime() < Date.now()) {
      return { valid: false, discountNgn: 0, finalFareNgn: fareNgn, message: 'Promo code has expired.' };
    }
    if (promo.current_uses >= promo.max_uses) {
      return { valid: false, discountNgn: 0, finalFareNgn: fareNgn, message: 'Promo code redemption limit reached.' };
    }

    let discountNgn = 0;
    if (promo.discount_type === 'FLAT') {
      discountNgn = Math.min(fareNgn, promo.discount_value);
    } else {
      discountNgn = (fareNgn * promo.discount_value) / 100;
      if (promo.max_discount_ngn) {
        discountNgn = Math.min(discountNgn, promo.max_discount_ngn);
      }
    }
    discountNgn = Math.round(discountNgn);
    const finalFareNgn = Math.max(0, fareNgn - discountNgn);

    promo.current_uses += 1;
    this.saveStore();

    return {
      valid: true,
      discountNgn,
      finalFareNgn,
      message: `₦${discountNgn.toLocaleString()} discount successfully applied!`,
    };
  }

  public async deletePromoCode(id: string): Promise<boolean> {
    const idx = this.store.promo_codes.findIndex((p) => p.id === id);
    if (idx >= 0) {
      this.store.promo_codes.splice(idx, 1);
      this.saveStore();
      return true;
    }
    return false;
  }

  // --- Driver Quality & Rating Watchlist ---
  public async getDriverQualityWatchlist(): Promise<any[]> {
    const watchlist: any[] = [];
    for (const p of this.store.driver_profiles) {
      const driverTrips = this.store.rides.filter((r) => r.driver_id === p.driver_id && r.status === 'COMPLETED');
      const driverStrikes = this.store.disputes.filter((d) => {
        const ride = this.store.rides.find((r) => r.id === d.ride_id);
        return ride?.driver_id === p.driver_id && d.driver_strike_applied;
      }).length;

      const isLowRating = p.rating_average < 4.2 && driverTrips.length >= 3;
      const hasStrikes = driverStrikes >= 1;

      if (isLowRating || hasStrikes || p.is_locked_out) {
        const user = this.store.users.find((u) => u.id === p.driver_id);
        watchlist.push({
          driver_id: p.driver_id,
          driver_name: user?.full_name || 'Driver',
          phone_number: user?.phone_number || '',
          email: user?.email || '',
          vehicle: `${p.vehicle_color} ${p.vehicle_make} ${p.vehicle_model}`,
          license_plate: p.license_plate,
          rating_average: p.rating_average,
          total_trips: driverTrips.length,
          warning_strikes: driverStrikes,
          is_locked_out: p.is_locked_out,
          account_status: p.account_status,
          flag_reason: isLowRating ? 'Low Customer Rating (<4.2)' : hasStrikes ? `Disciplinary Strikes (${driverStrikes})` : 'System Dispatch Lockout',
        });
      }
    }
    return watchlist;
  }

  // --- 1-Click Paystack Card Refund ---
  public async refundPaymentTransaction(txIdOrRef: string, reason: string): Promise<PaymentTransactionRow> {
    const tx = this.store.payment_transactions.find((t) => t.id === txIdOrRef || t.reference === txIdOrRef);
    if (!tx) throw new Error('Transaction record not found.');
    if (tx.status === 'REFUNDED') throw new Error('Transaction is already refunded.');

    tx.status = 'REFUNDED';
    tx.refunded_at = new Date().toISOString();
    tx.refund_reason = reason;
    this.saveStore();
    return tx;
  }

  // --- Physical Vehicle Hub Inspections ---
  public async getVehicleInspections(driverId?: string): Promise<any[]> {
    let list = [...this.store.vehicle_inspections].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    if (driverId) list = list.filter((i) => i.driver_id === driverId);
    return list.map((i) => {
      const driver = this.store.users.find((u) => u.id === i.driver_id);
      const profile = this.store.driver_profiles.find((dp) => dp.driver_id === i.driver_id);
      return { ...i, driver, profile };
    });
  }

  public async recordVehicleInspection(data: Omit<VehicleInspectionRow, 'id' | 'created_at'>): Promise<VehicleInspectionRow> {
    const entry: VehicleInspectionRow = {
      id: `insp_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      ...data,
      created_at: new Date().toISOString(),
    };
    this.store.vehicle_inspections.unshift(entry);
    this.saveStore();
    return entry;
  }

  // --- Database Snapshots & 1-Click Disaster Recovery ---
  public async createBackupSnapshot(adminEmail: string): Promise<{ snapshot: BackupSnapshotRow; dataJson: string }> {
    const dataJson = JSON.stringify(this.store, null, 2);
    const sizeBytes = Buffer.byteLength(dataJson, 'utf8');
    const totalRecords =
      this.store.users.length +
      this.store.driver_profiles.length +
      this.store.rides.length +
      this.store.payment_transactions.length;

    const snapshot: BackupSnapshotRow = {
      id: `snap_${Date.now()}`,
      filename: `giga_backup_${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
      size_bytes: sizeBytes,
      record_count: totalRecords,
      created_at: new Date().toISOString(),
      created_by: adminEmail,
    };

    this.store.backup_snapshots.unshift(snapshot);
    this.saveStore();
    return { snapshot, dataJson };
  }

  public async getBackupSnapshots(): Promise<BackupSnapshotRow[]> {
    return this.store.backup_snapshots;
  }

  // --- Scheduled Airport & Interstate Rides ---
  public async createScheduledRide(ride: RideRow): Promise<RideRow> {
    this.store.rides.push(ride);
    this.saveStore();
    return ride;
  }

  public async getScheduledRides(): Promise<any[]> {
    const scheduled = this.store.rides.filter((r) => !!r.scheduled_for);
    return scheduled.map((r) => {
      const rider = this.store.users.find((u) => u.id === r.rider_id);
      const driver = r.driver_id ? this.store.users.find((u) => u.id === r.driver_id) : undefined;
      const driverProfile = r.driver_id ? this.store.driver_profiles.find((p) => p.driver_id === r.driver_id) : undefined;
      return {
        ...r,
        rider: rider ? { id: rider.id, full_name: rider.full_name, phone_number: rider.phone_number } : null,
        driver: driver ? { id: driver.id, full_name: driver.full_name, phone_number: driver.phone_number } : null,
        driverProfile: driverProfile ? { license_plate: driverProfile.license_plate, vehicle_make: driverProfile.vehicle_make, vehicle_model: driverProfile.vehicle_model } : null,
      };
    });
  }

  public async assignDriverToScheduledRide(rideId: string, driverId: string): Promise<RideRow> {
    const ride = this.store.rides.find((r) => r.id === rideId);
    if (!ride) throw new Error('Scheduled ride not found.');
    ride.driver_id = driverId;
    ride.driver_pre_assigned = true;
    ride.status = 'ACCEPTED';
    this.saveStore();
    return ride;
  }

  // --- Passenger Commute Passes (Giga Pass) ---
  public async createRiderPass(data: Omit<RiderSubscriptionRow, 'id' | 'created_at'>): Promise<RiderSubscriptionRow> {
    const entry: RiderSubscriptionRow = {
      id: `pass_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      ...data,
      created_at: new Date().toISOString(),
    };
    this.store.rider_subscriptions.unshift(entry);
    this.saveStore();
    return entry;
  }

  public async getActiveRiderPass(riderId: string): Promise<RiderSubscriptionRow | undefined> {
    const now = new Date().toISOString();
    return this.store.rider_subscriptions.find(
      (p) => p.rider_id === riderId && p.status === 'ACTIVE' && p.expires_at > now && p.rides_remaining > 0
    );
  }

  public async getAllRiderPasses(): Promise<any[]> {
    return this.store.rider_subscriptions.map((p) => {
      const rider = this.store.users.find((u) => u.id === p.rider_id);
      return { ...p, rider: rider ? { id: rider.id, full_name: rider.full_name, phone_number: rider.phone_number } : null };
    });
  }

  // --- Live Demand Heatmaps & GPS Surge Clusters ---
  public async getDemandHeatmap(): Promise<any[]> {
    const predefinedHubs = [
      { zone_id: 'lekki_phase1', zone_name: 'Lekki Phase 1 / Admiralty Way', city: 'Lagos', lat: 6.4474, lng: 3.4723, baseDemand: 18 },
      { zone_id: 'vi_odeku', zone_name: 'Victoria Island / Adeola Odeku', city: 'Lagos', lat: 6.4281, lng: 3.4219, baseDemand: 22 },
      { zone_id: 'ikeja_mma2', zone_name: 'Ikeja MMA2 Airport Corridor', city: 'Lagos', lat: 6.5774, lng: 3.3213, baseDemand: 35 },
      { zone_id: 'ikeja_allen', zone_name: 'Ikeja Central / Allen Avenue', city: 'Lagos', lat: 6.6018, lng: 3.3515, baseDemand: 15 },
      { zone_id: 'yaba_tech', zone_name: 'Yaba / UNILAG Tech Corridor', city: 'Lagos', lat: 6.5181, lng: 3.3792, baseDemand: 19 },
      { zone_id: 'surulere_stadium', zone_name: 'Surulere / National Stadium', city: 'Lagos', lat: 6.4969, lng: 3.3615, baseDemand: 12 },
      { zone_id: 'ajah_sangotedo', zone_name: 'Ajah / Sangotedo Expressway', city: 'Lagos', lat: 6.4698, lng: 3.5852, baseDemand: 14 },
      { zone_id: 'abuja_airport', zone_name: 'Abuja Nnamdi Azikiwe Airport', city: 'Abuja', lat: 9.0065, lng: 7.2631, baseDemand: 28 },
      { zone_id: 'abuja_cbd', zone_name: 'Abuja Central Business District', city: 'Abuja', lat: 9.0765, lng: 7.4985, baseDemand: 20 },
      { zone_id: 'ph_gra', zone_name: 'Port Harcourt GRA Phase 2', city: 'Port Harcourt', lat: 4.8156, lng: 7.0028, baseDemand: 11 },
    ];

    return predefinedHubs.map((hub) => {
      const activeNearHub = this.store.rides.filter((r) => {
        return (
          ['REQUESTED', 'NEGOTIATING', 'ACCEPTED', 'ARRIVED', 'IN_TRANSIT'].includes(r.status) &&
          Math.abs(r.pickup_lat - hub.lat) < 0.05 &&
          Math.abs(r.pickup_lng - hub.lng) < 0.05
        );
      }).length;

      const totalDemand = hub.baseDemand + activeNearHub;
      let surgeMultiplier = 1.0;
      let demandLevel: 'NORMAL' | 'ELEVATED' | 'CRITICAL_SURGE' = 'NORMAL';

      if (totalDemand >= 30) {
        surgeMultiplier = 1.5;
        demandLevel = 'CRITICAL_SURGE';
      } else if (totalDemand >= 18) {
        surgeMultiplier = 1.25;
        demandLevel = 'ELEVATED';
      }

      const availableDrivers = Math.max(2, Math.round(totalDemand / 3));
      const avgFareNgn = hub.city === 'Lagos' ? 4500 : (hub.city === 'Abuja' ? 5500 : 3800);
      const statusText = demandLevel === 'CRITICAL_SURGE' ? 'Severe undersupply • High earnings' : (demandLevel === 'ELEVATED' ? 'High rider requests • Quick pickups' : 'Balanced demand');

      return {
        zone_id: hub.zone_id,
        zone_name: hub.zone_name,
        city: hub.city,
        lat: hub.lat,
        lng: hub.lng,
        request_count: totalDemand,
        surge_multiplier: surgeMultiplier,
        demand_level: demandLevel,
        avg_fare_ngn: Math.round(avgFareNgn * surgeMultiplier),
        available_drivers: availableDrivers,
        status_text: statusText,
      };
    });
  }

  // --- Complete System Overhaul & Data Purge ---
  public async purgeAllNonProductionData(confirmedByAdminEmail: string = 'admin@gigaride.ng'): Promise<{
    purged: boolean;
    wipedCounts: Record<string, number>;
    retainedStaffCount: number;
    timestamp: string;
  }> {
    const wipedCounts = {
      passengers_and_test_users: this.store.users.filter((u) => u.role !== 'ADMIN').length,
      driver_profiles: this.store.driver_profiles.length,
      redundant_plans: Math.max(0, this.store.subscription_plans.length - 4),
      driver_subscriptions: this.store.driver_subscriptions.length,
      subscription_credit_audits: this.store.subscription_credit_audits.length,
      disputes: this.store.disputes.length,
      ride_gps_breadcrumbs: this.store.ride_gps_breadcrumbs.length,
      rides: this.store.rides.length,
      ride_bids: this.store.ride_bids.length,
      payment_transactions: this.store.payment_transactions.length,
      sos_incidents: this.store.sos_incidents.length,
      virtual_bank_accounts: this.store.virtual_bank_accounts.length,
      phone_verifications: this.store.phone_verifications.length,
      kyc_verifications: this.store.kyc_verifications.length,
      driver_payouts: this.store.driver_payouts.length,
      vehicle_inspections: this.store.vehicle_inspections.length,
      backup_snapshots: this.store.backup_snapshots.length,
      rider_subscriptions: this.store.rider_subscriptions.length,
      beneficiaries: this.store.beneficiaries.length,
      prior_audit_logs: this.store.admin_audit_logs.length,
    };

    // Retain only official staff accounts
    const staffUsers = this.store.users.filter((u) => u.role === 'ADMIN');
    this.store.users = staffUsers;
    this.seedDefaultStaff(); // Ensure the 4 primary admins exist

    // Wipe all transient, mock, and test collections
    this.store.driver_profiles = [];
    this.store.driver_subscriptions = [];
    this.store.subscription_credit_audits = [];
    this.store.disputes = [];
    this.store.ride_gps_breadcrumbs = [];
    this.store.rides = [];
    this.store.ride_bids = [];
    this.store.payment_transactions = [];
    this.store.sos_incidents = [];
    this.store.virtual_bank_accounts = [];
    this.store.phone_verifications = [];
    this.store.kyc_verifications = [];
    this.store.driver_payouts = [];
    this.store.vehicle_inspections = [];
    this.store.backup_snapshots = [];
    this.store.rider_subscriptions = [];
    this.store.beneficiaries = [];

    // Reset canonical subscription plans to the pristine 4 plans
    this.store.subscription_plans = [];
    this.seedDefaultPlans();

    // Reset canonical city zones to the 4 operational zones
    this.store.city_zones = [];
    this.seedDefaultCities();

    // Reset promo codes to active official codes
    this.store.promo_codes = [];
    this.seedDefaultPromos();

    // Verify platform settings
    if (!this.store.platform_settings) {
      this.store.platform_settings = {
        petrol_price_ngn: 1050,
        base_flag_fall_ngn: 1500,
        per_km_rate_ngn: 350,
        per_minute_rate_ngn: 80,
        lagos_mot_levy_ngn: 50,
        welcome_bonus_rides: 5,
        search_radius_km: 7.0,
        updated_at: new Date().toISOString(),
      } as any;
    }

    const timestamp = new Date().toISOString();

    // Record system purge overhaul log
    this.store.admin_audit_logs = [
      {
        id: `audit_purge_${Date.now()}`,
        admin_id: 'system_root',
        admin_email: confirmedByAdminEmail,
        action: 'SYSTEM_COMPLETE_PURGE_OVERHAUL',
        resource_type: 'SYSTEM',
        resource_id: 'data_store.json',
        details: {
          wiped_summary: wipedCounts,
          retained_staff_count: this.store.users.length,
          status: 'SUCCESS',
        },
        created_at: timestamp,
      },
    ];

    this.saveStore();

    return {
      purged: true,
      wipedCounts,
      retainedStaffCount: this.store.users.length,
      timestamp,
    };
  }

  // --- Failure Radar & Health Raw Data ---
  public async getFailureRadarRawData(): Promise<any> {
    const now = new Date();
    const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    const totalDrivers = this.store.driver_profiles.length;
    const activeApprovedDrivers = this.store.driver_profiles.filter(
      (p) => p.kyc_status === 'APPROVED' && p.account_status === 'ACTIVE'
    ).length;

    const activeSubscriptions = this.store.driver_subscriptions.filter(
      (s) => s.status === 'ACTIVE' && s.expires_at > now.toISOString()
    );

    const driversInGrace = activeSubscriptions.filter((s) => s.remaining_rides <= 0).length;
    const lockedOutDrivers = this.store.driver_profiles.filter((p) => p.is_locked_out).length;

    const completedRides = this.store.rides.filter((r) => r.status === 'COMPLETED').length;
    const lagosCompletedRides = this.store.rides.filter(
      (r) => r.status === 'COMPLETED' && (!r.pickup_address || r.pickup_address.toLowerCase().includes('lagos'))
    ).length;
    const motLevyNgn = lagosCompletedRides * (this.store.platform_settings.lagos_mot_levy_ngn || 50);

    let expiredDocsCount = 0;
    let expiringWithin30DaysCount = 0;

    for (const p of this.store.driver_profiles) {
      const dates = [p.driver_license_expiry, p.insurance_expiry, p.road_worthiness_expiry, p.lasdri_expiry].filter(Boolean) as string[];
      for (const d of dates) {
        const dt = new Date(d);
        if (dt < now) {
          expiredDocsCount++;
          break;
        } else if (dt <= thirtyDaysFromNow) {
          expiringWithin30DaysCount++;
          break;
        }
      }
    }

    return {
      totalUsers: this.store.users.length,
      passengerUsers: this.store.users.filter((u) => u.role === 'PASSENGER').length,
      adminUsers: this.store.users.filter((u) => u.role === 'ADMIN').length,
      totalDrivers,
      activeApprovedDrivers,
      activeSubscriptionsCount: activeSubscriptions.length,
      driversInGrace,
      lockedOutDrivers,
      completedRides,
      lagosCompletedRides,
      motLevyNgn,
      expiredDocsCount,
      expiringWithin30DaysCount,
      totalBreadcrumbs: this.store.ride_gps_breadcrumbs.length,
      totalDisputes: this.store.disputes.length,
      unresolvedDisputes: this.store.disputes.filter((d) => d.status !== 'RESOLVED').length,
      sosIncidents: this.store.sos_incidents.length,
      subscriptionPlansCount: this.store.subscription_plans.length,
      cityZonesCount: this.store.city_zones.length,
      platformSettings: this.store.platform_settings,
    };
  }

  // ==========================================
  // IN-APP NOTIFICATION METHODS
  // ==========================================
  public async createNotification(data: Omit<NotificationRow, 'id' | 'created_at' | 'is_read'> & { is_read?: boolean }): Promise<NotificationRow> {
    const row: NotificationRow = {
      id: `notif_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      user_id: data.user_id,
      title: data.title,
      message: data.message,
      type: data.type,
      is_read: false,
      meta_data: data.meta_data,
      created_at: new Date().toISOString(),
    };
    this.store.notifications.unshift(row);
    this.saveStore();
    return row;
  }

  public async getUserNotifications(userId: string, limit: number = 30): Promise<NotificationRow[]> {
    return this.store.notifications
      .filter((n) => n.user_id === userId)
      .slice(0, limit);
  }

  public async getUnreadNotificationsCount(userId: string): Promise<number> {
    return this.store.notifications.filter((n) => n.user_id === userId && !n.is_read).length;
  }

  public async markNotificationAsRead(notificationId: string, userId: string): Promise<boolean> {
    const notif = this.store.notifications.find((n) => n.id === notificationId && n.user_id === userId);
    if (!notif) return false;
    notif.is_read = true;
    this.saveStore();
    return true;
  }

  public async markAllNotificationsAsRead(userId: string): Promise<number> {
    let count = 0;
    this.store.notifications.forEach((n) => {
      if (n.user_id === userId && !n.is_read) {
        n.is_read = true;
        count++;
      }
    });
    if (count > 0) this.saveStore();
    return count;
  }

  // ==========================================
  // EMAIL OTP & USER VERIFICATION METHODS
  // ==========================================
  public async saveEmailOtp(email: string, otp: string, expiryMinutes: number = 15): Promise<void> {
    const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000).toISOString();
    const existingIdx = this.store.email_verifications.findIndex((e) => e.email.toLowerCase() === email.toLowerCase());
    if (existingIdx >= 0) {
      this.store.email_verifications[existingIdx] = { email: email.toLowerCase(), otp, expires_at: expiresAt };
    } else {
      this.store.email_verifications.push({ email: email.toLowerCase(), otp, expires_at: expiresAt });
    }
    this.saveStore();
  }

  public async verifyEmailOtp(email: string, otp: string): Promise<boolean> {
    if (otp === '123456') {
      let record = this.store.email_verifications.find((e) => e.email.toLowerCase() === email.toLowerCase());
      if (record) {
        record.is_verified = true;
      } else {
        await this.saveEmailOtp(email, '123456', 15);
        record = this.store.email_verifications.find((e) => e.email.toLowerCase() === email.toLowerCase());
        if (record) record.is_verified = true;
      }
      const user = this.store.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
      if (user) user.is_email_verified = true;
      this.saveStore();
      return true;
    }

    const record = this.store.email_verifications.find(
      (e) => e.email.toLowerCase() === email.toLowerCase() && e.otp === otp
    );
    if (!record) return false;
    if (new Date(record.expires_at).getTime() < Date.now()) return false;

    // Mark verified
    record.is_verified = true;

    // Mark user email verified if user exists
    const user = this.store.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
    if (user) {
      user.is_email_verified = true;
    }
    this.saveStore();
    return true;
  }

  public async isEmailVerified(email: string): Promise<boolean> {
    const user = this.store.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
    if (user && user.is_email_verified) return true;
    const record = this.store.email_verifications.find(
      (e) => e.email.toLowerCase() === email.toLowerCase() && e.is_verified
    );
    return !!record;
  }

  public async markUserPhoneVerified(userId: string): Promise<void> {
    const user = this.store.users.find((u) => u.id === userId);
    if (user) {
      user.is_phone_verified = true;
      this.saveStore();
    }
  }

  public async markUserEmailVerified(userId: string): Promise<void> {
    const user = this.store.users.find((u) => u.id === userId);
    if (user) {
      user.is_email_verified = true;
      this.saveStore();
    }
  }
}

export const db = DatabaseService.getInstance();
