export interface CreateRideRequestDto {
  pickupLat: number;
  pickupLng: number;
  pickupAddress: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffAddress: string;
  riderOfferNgn: number;
  riderName?: string | null;
  riderPhone?: string | null;
  riderType?: 'SELF' | 'FRIEND' | null;
  notes?: string | null;
  isBusiness?: boolean | null;
  hasWaitTime?: boolean | null;
  requestedWaitMinutes?: number | null;
  distanceKm?: number | null;
  durationMinutes?: number | null;
}

export interface FareEstimateDto {
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  distanceKm?: number | null;
  durationMinutes?: number | null;
}
