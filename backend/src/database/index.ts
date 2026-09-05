import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { ENV } from '../config/env';

export interface UserRow {
  id: string;
  role: 'PASSENGER' | 'DRIVER' | 'ADMIN';
  full_name: string;
  phone_number: string;
  email: string;
  password_hash: string;
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
  rating_average: number;
  total_trips_completed: number;
  is_online: boolean;
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

export interface PaymentTransactionRow {
  id: string;
  reference: string;
  user_id: string;
  amount_kobo: number;
  status: 'PENDING' | 'SUCCESS' | 'FAILED';
  payment_type: 'SUBSCRIPTION_PURCHASE';
  channel: string;
  meta_data: any;
  created_at: string;
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

export interface PlatformSettingsRow {
  petrol_price_ngn: number;
  base_flag_fall_ngn: number;
  per_km_rate_ngn: number;
  per_minute_rate_ngn: number;
  lagos_mot_levy_ngn: number;
  welcome_bonus_rides: number;
  search_radius_km: number;
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
    rides: [] as RideRow[],
    ride_bids: [] as RideBidRow[],
    payment_transactions: [] as PaymentTransactionRow[],
    sos_incidents: [] as SosIncidentRow[],
    platform_settings: {
      petrol_price_ngn: 1050,
      base_flag_fall_ngn: 1500,
      per_km_rate_ngn: 350,
      per_minute_rate_ngn: 80,
      lagos_mot_levy_ngn: 50,
      welcome_bonus_rides: 5,
      search_radius_km: 7.0,
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
      } catch {
        this.saveStore();
      }
    } else {
      this.seedDefaultPlans();
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

  public async getPassengers(): Promise<(UserRow & { totalRides: number })[]> {
    return this.store.users
      .filter((u) => u.role === 'PASSENGER')
      .map((u) => {
        const totalRides = this.store.rides.filter((r) => r.rider_id === u.id && r.status === 'COMPLETED').length;
        return { ...u, totalRides };
      });
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

    return {
      profile,
      user,
      subscriptions,
      creditAudits,
      totalTrips: trips.length,
      completedTrips: trips.filter((t) => t.status === 'COMPLETED').length,
    };
  }

  public async updateDriverOnlineStatus(driverId: string, isOnline: boolean): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
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
      .filter((s) => s.driver_id === driverId && s.expires_at > now && (s.status === 'ACTIVE' || s.remaining_rides > -ENV.MAX_GRACE_RIDES))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
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
}

export const db = DatabaseService.getInstance();
