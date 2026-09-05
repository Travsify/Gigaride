import { db, PlatformSettingsRow } from '../../database';
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

  public async reviewKyc(driverId: string, status: 'APPROVED' | 'REJECTED', rejectionReason?: string) {
    await db.updateDriverKyc(driverId, status, rejectionReason);
    return { driverId, status, rejectionReason };
  }

  public async setDriverAccountStatus(driverId: string, accountStatus: 'ACTIVE' | 'SUSPENDED' | 'BANNED') {
    await db.setDriverAccountStatus(driverId, accountStatus);
    if (accountStatus !== 'ACTIVE') {
      // Evict from active geo session
      geoSessionManager.removeDriver(driverId);
    }
    return { driverId, accountStatus };
  }

  public async manualCreditRides(adminId: string, driverId: string, ridesToAdd: number, reason: string) {
    if (ridesToAdd <= 0) throw new Error('Rides to credit must be greater than 0.');
    if (!reason || reason.trim().length < 3) throw new Error('A detailed operational reason is required for audit logs.');

    const updatedSub = await db.addManualRideCredit(adminId, driverId, ridesToAdd, reason);

    // Refresh live driver presence in Redis / GeoStore
    const loc = geoSessionManager.getDriverLocation(driverId);
    if (loc) {
      loc.hasActiveSubscription = true;
      loc.remainingRides = updatedSub.remaining_rides;
      geoSessionManager.updateDriverLocation(loc);
    }

    return updatedSub;
  }

  public async getCreditAudits(driverId?: string) {
    return db.getCreditAudits(driverId);
  }

  public async getActiveRides() {
    return db.getActiveRides();
  }

  public async getLiveFleet() {
    // Gather all online drivers from DB and geo cache
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

  public async resolveSosIncident(id: string, notes: string) {
    await db.resolveSosIncident(id, notes);
    return { id, status: 'RESOLVED', notes };
  }

  public async getPlatformSettings(): Promise<PlatformSettingsRow> {
    return db.getPlatformSettings();
  }

  public async updatePlatformSettings(settings: Partial<PlatformSettingsRow>): Promise<PlatformSettingsRow> {
    return db.updatePlatformSettings(settings);
  }

  public async getPassengers() {
    return db.getPassengers();
  }

  public async getTransactions() {
    return db.getTransactions();
  }
}

export const adminService = new AdminService();
