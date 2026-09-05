import { ENV } from '../config/env';
import { calculateHaversineDistanceKm, estimateTravelTimeMinutes } from './geo';

export interface FareEstimate {
  distanceKm: number;
  estimatedMinutes: number;
  suggestedFareNgn: number;
  minimumBidFloorNgn: number;
  fuelCostEstimateNgn: number;
  breakdown: {
    baseFlagFallNgn: number;
    distanceChargeNgn: number;
    timeChargeNgn: number;
    regulatoryLevyNgn: number;
  };
}

/**
 * Calculates suggested fare and minimum bidding floor based on real Nigerian economic metrics
 * (PMS fuel cost per litre, distance, urban travel time, and regulatory fees).
 */
export function calculateSuggestedFare(
  pickupLat: number,
  pickupLng: number,
  dropoffLat: number,
  dropoffLng: number
): FareEstimate {
  const distanceKm = calculateHaversineDistanceKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
  const estimatedMinutes = estimateTravelTimeMinutes(distanceKm);

  // Typical fuel consumption for 1.8L–2.4L engine (Corolla, Camry, Pontiac Vibe common in Lagos)
  // Average ~10km per litre in stop-and-go traffic
  const estimatedLitresUsed = distanceKm / 10.0;
  const fuelCostEstimateNgn = Math.round(estimatedLitresUsed * ENV.PETROL_PRICE_PER_LITRE_NGN);

  const baseFlagFall = ENV.BASE_FLAG_FALL_NGN;
  const distanceCharge = Math.round(distanceKm * ENV.PER_KM_RATE_NGN);
  const timeCharge = Math.round(estimatedMinutes * ENV.PER_MINUTE_RATE_NGN);
  const regulatoryLevy = ENV.LAGOS_MOT_LEVY_NGN;

  // Raw computed fare
  const rawFare = baseFlagFall + distanceCharge + timeCharge + regulatoryLevy;

  // Round up to nearest 100 NGN for easy Nigerian currency handling
  const suggestedFareNgn = Math.ceil(rawFare / 100) * 100;

  // The floor bid prevents unrealistic passenger lowballing that drivers reject:
  // Floor is set to ensure fuel is covered + at least 70% of base fare.
  const minimumFloor = Math.max(
    1500,
    Math.ceil((fuelCostEstimateNgn + baseFlagFall * 0.7) / 100) * 100
  );

  return {
    distanceKm,
    estimatedMinutes,
    suggestedFareNgn,
    minimumBidFloorNgn: Math.min(minimumFloor, suggestedFareNgn),
    fuelCostEstimateNgn,
    breakdown: {
      baseFlagFallNgn: baseFlagFall,
      distanceChargeNgn: distanceCharge,
      timeChargeNgn: timeCharge,
      regulatoryLevyNgn: regulatoryLevy,
    },
  };
}
