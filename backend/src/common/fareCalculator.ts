import { ENV } from '../config/env';
import { db, PlatformSettingsRow } from '../database';
import { calculateHaversineDistanceKm, estimateTravelTimeMinutes } from './geo';

export interface FareEstimate {
  distanceKm: number;
  estimatedMinutes: number;
  suggestedFareNgn: number;
  recommendedFareNgn: number; // alias for frontend compatibility
  estimatedFareNgn: number;   // alias for frontend compatibility
  minimumBidFloorNgn: number;
  fuelCostEstimateNgn: number;
  petrolPricePerLitreNgn: number;
  tiers: {
    economyFareNgn: number;
    comfortFareNgn: number;
    xlSuvFareNgn: number;
  };
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
 * Supports real-time dynamic platform settings from database.
 */
export function calculateSuggestedFare(
  pickupLat: number,
  pickupLng: number,
  dropoffLat: number,
  dropoffLng: number,
  customSettings?: PlatformSettingsRow,
  roadDistanceKm?: number | null,
  roadDurationMinutes?: number | null
): FareEstimate {
  const straightLineDistanceKm = calculateHaversineDistanceKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
  // Real road network is typically 1.3x straight line if road distance is not supplied
  const distanceKm = (roadDistanceKm && roadDistanceKm > 0)
    ? Number(roadDistanceKm.toFixed(2))
    : Number((straightLineDistanceKm * 1.3).toFixed(2));

  const estimatedMinutes = (roadDurationMinutes && roadDurationMinutes > 0)
    ? Math.round(roadDurationMinutes)
    : estimateTravelTimeMinutes(distanceKm);

  const petrolPrice = customSettings ? customSettings.petrol_price_ngn : ENV.PETROL_PRICE_PER_LITRE_NGN;
  const baseFlagFall = customSettings ? customSettings.base_flag_fall_ngn : ENV.BASE_FLAG_FALL_NGN;
  const perKmRate = customSettings ? customSettings.per_km_rate_ngn : ENV.PER_KM_RATE_NGN;
  const perMinuteRate = customSettings ? customSettings.per_minute_rate_ngn : ENV.PER_MINUTE_RATE_NGN;
  const regulatoryLevy = customSettings ? customSettings.lagos_mot_levy_ngn : ENV.LAGOS_MOT_LEVY_NGN;

  // Progressive distance rate: Short trips have higher per-km rate to ensure driver viability
  let effectivePerKm = perKmRate;
  if (distanceKm < 4.0) {
    effectivePerKm = Math.round(perKmRate * 1.25);
  } else if (distanceKm > 15.0) {
    effectivePerKm = Math.round(perKmRate * 0.90);
  }

  // Typical fuel consumption for 1.8L–2.4L engine (Corolla, Camry in Nigerian cities ~10 km/L)
  const estimatedLitresUsed = distanceKm / 10.0;
  const fuelCostEstimateNgn = Math.round(estimatedLitresUsed * petrolPrice);

  const distanceCharge = Math.round(distanceKm * effectivePerKm);
  const timeCharge = Math.round(estimatedMinutes * perMinuteRate);

  // Raw computed fare rounded to nearest ₦100
  const rawFare = baseFlagFall + distanceCharge + timeCharge + regulatoryLevy;
  const suggestedFareNgn = Math.ceil(rawFare / 100) * 100;

  // Minimum floor ensures fuel + 70% of base flag fall is covered
  const minimumFloor = Math.max(
    1500,
    Math.ceil((fuelCostEstimateNgn + baseFlagFall * 0.7) / 100) * 100
  );

  return {
    distanceKm,
    estimatedMinutes,
    suggestedFareNgn,
    recommendedFareNgn: suggestedFareNgn,
    estimatedFareNgn: suggestedFareNgn,
    minimumBidFloorNgn: Math.min(minimumFloor, suggestedFareNgn),
    fuelCostEstimateNgn,
    petrolPricePerLitreNgn: petrolPrice,
    tiers: {
      economyFareNgn: suggestedFareNgn,
      comfortFareNgn: Math.ceil((suggestedFareNgn * 1.25) / 100) * 100,
      xlSuvFareNgn: Math.ceil((suggestedFareNgn * 1.70) / 100) * 100,
    },
    breakdown: {
      baseFlagFallNgn: baseFlagFall,
      distanceChargeNgn: distanceCharge,
      timeChargeNgn: timeCharge,
      regulatoryLevyNgn: regulatoryLevy,
    },
  };
}

export async function calculateSuggestedFareWithDb(
  pickupLat: number,
  pickupLng: number,
  dropoffLat: number,
  dropoffLng: number,
  roadDistanceKm?: number | null,
  roadDurationMinutes?: number | null
): Promise<FareEstimate> {
  const settings = await db.getPlatformSettings();
  return calculateSuggestedFare(
    pickupLat,
    pickupLng,
    dropoffLat,
    dropoffLng,
    settings,
    roadDistanceKm,
    roadDurationMinutes
  );
}
