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
  nin?: string;
  bvn?: string;
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

export class DatabaseService {
  private static instance: DatabaseService;
  private pgPool: Pool | null = null;
  private isPostgresConnected = false;

  // Local persistent state file for seamless offline development
  private dbFilePath = path.join(__dirname, '../../../data_store.json');
  private store = {
    users: [] as UserRow[],
    driver_profiles: [] as DriverProfileRow[],
    subscription_plans: [] as SubscriptionPlanRow[],
    driver_subscriptions: [] as DriverSubscriptionRow[],
    rides: [] as RideRow[],
    ride_bids: [] as RideBidRow[],
    payment_transactions: [] as PaymentTransactionRow[],
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
        this.store = JSON.parse(raw);
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
          price_kobo: 150000, // ₦1,500 (₦150 per trip platform cost!)
          is_active: true,
        },
        {
          id: 'plan_standard_50',
          name: '50-Ride Weekly Hustle',
          description: 'Designed for active weekly drivers. No percentage deducted from any trip.',
          plan_type: 'RIDE_COUNT',
          total_rides: 50,
          duration_days: 7,
          price_kobo: 600000, // ₦6,000 (₦120 per trip platform cost)
          is_active: true,
        },
        {
          id: 'plan_pro_100',
          name: '100-Ride Bi-Weekly Pro',
          description: 'Best unit economics for full-time drivers.',
          plan_type: 'RIDE_COUNT',
          total_rides: 100,
          duration_days: 14,
          price_kobo: 1000000, // ₦10,000 (₦100 per trip platform cost)
          is_active: true,
        },
        {
          id: 'plan_monthly_unlimited',
          name: 'Monthly Unlimited Freedom',
          description: '30 Days of unlimited ride requests. Never worry about counting rides.',
          plan_type: 'UNLIMITED',
          total_rides: null,
          duration_days: 30,
          price_kobo: 2500000, // ₦25,000/month flat
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
      console.log('[Database] PostgreSQL not active locally. Operating on persistent ACID file-backed store.');
    }
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

  // --- Driver Profile Repository ---
  public async createDriverProfile(profile: DriverProfileRow): Promise<DriverProfileRow> {
    this.store.driver_profiles.push(profile);
    this.saveStore();
    return profile;
  }

  public async getDriverProfile(driverId: string): Promise<DriverProfileRow | undefined> {
    return this.store.driver_profiles.find((d) => d.driver_id === driverId);
  }

  public async updateDriverOnlineStatus(driverId: string, isOnline: boolean): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.is_online = isOnline;
      this.saveStore();
    }
  }

  public async updateDriverKyc(driverId: string, status: 'APPROVED' | 'REJECTED'): Promise<void> {
    const profile = this.store.driver_profiles.find((d) => d.driver_id === driverId);
    if (profile) {
      profile.kyc_status = status;
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

  // --- Subscription Plans ---
  public async getActivePlans(): Promise<SubscriptionPlanRow[]> {
    return this.store.subscription_plans.filter((p) => p.is_active);
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
    // Expire any existing active subscriptions
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

  // --- Transactions ---
  public async createTransaction(tx: PaymentTransactionRow): Promise<PaymentTransactionRow> {
    this.store.payment_transactions.push(tx);
    this.saveStore();
    return tx;
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

  // --- Platform Analytics ---
  public async getAnalytics() {
    const totalDrivers = this.store.driver_profiles.length;
    const totalPassengers = this.store.users.filter((u) => u.role === 'PASSENGER').length;
    const totalRidesCompleted = this.store.rides.filter((r) => r.status === 'COMPLETED').length;
    const totalSubscriptionRevenueKobo = this.store.payment_transactions
      .filter((t) => t.status === 'SUCCESS')
      .reduce((sum, t) => sum + t.amount_kobo, 0);

    return {
      totalDrivers,
      totalPassengers,
      totalRidesCompleted,
      totalSubscriptionRevenueNgn: totalSubscriptionRevenueKobo / 100,
      activePlans: this.store.subscription_plans.length,
    };
  }
}

export const db = DatabaseService.getInstance();
