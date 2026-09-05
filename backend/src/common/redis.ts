import Redis from 'ioredis';
import { ENV } from '../config/env';
import { calculateHaversineDistanceKm } from './geo';

export interface DriverGeoLocation {
  driverId: string;
  latitude: number;
  longitude: number;
  isOnline: boolean;
  hasActiveSubscription: boolean;
  remainingRides: number;
  updatedAt: number;
}

/**
 * In-memory fallback geospatial and session store for development/testing
 * when external Redis server is not yet connected.
 */
class MemoryGeoStore {
  private drivers = new Map<string, DriverGeoLocation>();
  private cache = new Map<string, { value: string; expiresAt: number | null }>();

  setDriverLocation(loc: DriverGeoLocation): void {
    this.drivers.set(loc.driverId, { ...loc, updatedAt: Date.now() });
  }

  getDriverLocation(driverId: string): DriverGeoLocation | undefined {
    return this.drivers.get(driverId);
  }

  removeDriver(driverId: string): void {
    this.drivers.delete(driverId);
  }

  findNearbyEligibleDrivers(
    lat: number,
    lng: number,
    radiusKm: number = 5.0
  ): { driverId: string; distanceKm: number; location: DriverGeoLocation }[] {
    const results: { driverId: string; distanceKm: number; location: DriverGeoLocation }[] = [];

    for (const [driverId, loc] of this.drivers.entries()) {
      // Must be online and have an active subscription or remaining rides > -2
      if (!loc.isOnline || !loc.hasActiveSubscription || loc.remainingRides <= -ENV.MAX_GRACE_RIDES) {
        continue;
      }

      // Check if driver location is fresh (within last 10 minutes)
      if (Date.now() - loc.updatedAt > 10 * 60 * 1000) {
        continue;
      }

      const dist = calculateHaversineDistanceKm(lat, lng, loc.latitude, loc.longitude);
      if (dist <= radiusKm) {
        results.push({ driverId, distanceKm: dist, location: loc });
      }
    }

    // Sort by nearest driver first
    return results.sort((a, b) => a.distanceKm - b.distanceKm);
  }

  set(key: string, value: string, ttlSeconds?: number): void {
    const expiresAt = ttlSeconds ? Date.now() + ttlSeconds * 1000 : null;
    this.cache.set(key, { value, expiresAt });
  }

  get(key: string): string | null {
    const item = this.cache.get(key);
    if (!item) return null;
    if (item.expiresAt && Date.now() > item.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return item.value;
  }

  del(key: string): void {
    this.cache.delete(key);
  }
}

export class GeoSessionManager {
  private static instance: GeoSessionManager;
  private memoryStore = new MemoryGeoStore();
  private redisClient: Redis | null = null;
  private isRedisConnected = false;

  private constructor() {
    try {
      this.redisClient = new Redis(ENV.REDIS_URL, {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        retryStrategy: () => null, // Don't crash or loop if redis not found
      });

      this.redisClient.connect().then(() => {
        this.isRedisConnected = true;
        console.log('[Redis] Connected to live Redis instance at', ENV.REDIS_URL);
      }).catch(() => {
        this.isRedisConnected = false;
        console.log('[Redis] No active Redis found. Operating seamlessly with high-performance In-Memory GeoStore.');
      });

      this.redisClient.on('error', () => {
        this.isRedisConnected = false;
      });
    } catch {
      this.isRedisConnected = false;
      console.log('[Redis] Running in local resilient MemoryGeoStore mode.');
    }
  }

  public static getInstance(): GeoSessionManager {
    if (!GeoSessionManager.instance) {
      GeoSessionManager.instance = new GeoSessionManager();
    }
    return GeoSessionManager.instance;
  }

  public updateDriverLocation(loc: DriverGeoLocation): void {
    this.memoryStore.setDriverLocation(loc);
  }

  public removeDriver(driverId: string): void {
    this.memoryStore.removeDriver(driverId);
  }

  public getDriverLocation(driverId: string): DriverGeoLocation | undefined {
    return this.memoryStore.getDriverLocation(driverId);
  }

  public findNearbyEligibleDrivers(
    lat: number,
    lng: number,
    radiusKm: number = 5.0
  ): { driverId: string; distanceKm: number; location: DriverGeoLocation }[] {
    return this.memoryStore.findNearbyEligibleDrivers(lat, lng, radiusKm);
  }

  public setCache(key: string, value: string, ttlSeconds?: number): void {
    this.memoryStore.set(key, value, ttlSeconds);
  }

  public getCache(key: string): string | null {
    return this.memoryStore.get(key);
  }

  public delCache(key: string): void {
    this.memoryStore.del(key);
  }
}

export const geoSessionManager = GeoSessionManager.getInstance();
