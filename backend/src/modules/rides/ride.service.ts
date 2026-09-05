import { v4 as uuidv4 } from 'uuid';
import { db, RideRow } from '../../database';
import { calculateSuggestedFare, calculateSuggestedFareWithDb } from '../../common/fareCalculator';
import { CreateRideRequestDto } from './ride.types';

export class RideService {
  /**
   * Calculates real fare estimate with floor guardrails.
   */
  public async getFareEstimate(pickupLat: number, pickupLng: number, dropoffLat: number, dropoffLng: number) {
    return calculateSuggestedFareWithDb(pickupLat, pickupLng, dropoffLat, dropoffLng);
  }

  /**
   * Creates a ride request in NEGOTIATING status.
   */
  public async createRide(riderId: string, dto: CreateRideRequestDto): Promise<RideRow> {
    const estimate = await calculateSuggestedFareWithDb(
      dto.pickupLat,
      dto.pickupLng,
      dto.dropoffLat,
      dto.dropoffLng
    );

    // Validate offer against floor
    if (dto.riderOfferNgn < estimate.minimumBidFloorNgn) {
      throw new Error(
        `Offer ₦${dto.riderOfferNgn.toLocaleString()} is below the minimum floor of ₦${estimate.minimumBidFloorNgn.toLocaleString()}. Please increase your offer so drivers can accept.`
      );
    }

    const rideId = uuidv4();
    const ride: RideRow = {
      id: rideId,
      rider_id: riderId,
      driver_id: null,
      pickup_lat: dto.pickupLat,
      pickup_lng: dto.pickupLng,
      pickup_address: dto.pickupAddress,
      dropoff_lat: dto.dropoffLat,
      dropoff_lng: dto.dropoffLng,
      dropoff_address: dto.dropoffAddress,
      suggested_fare_ngn: estimate.suggestedFareNgn,
      rider_offer_ngn: dto.riderOfferNgn,
      agreed_fare_ngn: null,
      distance_km: estimate.distanceKm,
      status: 'NEGOTIATING',
      created_at: new Date().toISOString(),
    };

    return db.createRide(ride);
  }

  public async getRide(rideId: string): Promise<RideRow | undefined> {
    return db.getRideById(rideId);
  }

  public async getRiderHistory(riderId: string): Promise<RideRow[]> {
    return db.getRiderHistory(riderId);
  }

  public async getDriverHistory(driverId: string): Promise<RideRow[]> {
    return db.getDriverHistory(driverId);
  }
}

export const rideService = new RideService();
