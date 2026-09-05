import { ENV } from '../config/env';
import { db, PlatformSettingsRow } from '../database';
import { calculateHaversineDistanceKm, estimateTravelTimeMinutes } from './geo';

export interface FareEstimate {
  distanceKm: number;
  estimatedMinutes: number;
  suggestedFareNgn: number;
  minimumBidFloorNgn: number;
  fuelCostEstimateNgn: number;
  petrolPricePerLitreNgn: number;
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
  customSettings?: PlatformSettingsRow
): FareEstimate {
  const distanceKm = calculateHaversineDistanceKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
  const estimatedMinutes = estimateTravelTimeMinutes(distanceKm);

  const petrolPrice = customSettings ? customSettings.petrol_price_ngn : ENV.PETROL_PRICE_PER_LITRE_NGN;
  const baseFlagFall = customSettings ? customSettings.base_flag_fall_ngn : ENV.BASE_FLAG_FALL_NGN;
  const perKmRate = customSettings ? customSettings.per_km_rate_ngn : ENV.PER_KM_RATE_NGN;
  const perMinuteRate = customSettings ? customSettings.per_minute_rate_ngn : ENV.PER_MINUTE_RATE_NGN;
  const regulatoryLevy = customSettings ? customSettings.lagos_mot_levy_ngn : ENV.LAGOS_MOT_LEVY_NGN;

  // Typical fuel consumption for 1.8L–2.4L engine (Corolla, Camry in Lagos)
  const estimatedLitresUsed = distanceKm / 10.0;
  const fuelCostEstimateNgn = Math.round(estimatedLitresUsed * petrolPrice);

  const distanceCharge = Math.round(distanceKm * perKmRate);
  const timeCharge = Math.round(estimatedMinutes * perMinuteRate);

  // Raw computed fare
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
    minimumBidFloorNgn: Math.min(minimumFloor, suggestedFareNgn),
    fuelCostEstimateNgn,
    petrolPricePerLitreNgn: petrolPrice,
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
  dropoffLng: number
): Promise<FareEstimate> {
  const settings = await db.getPlatformSettings();
  return calculateSuggestedFare(pickupLat, pickupLng, dropoffLat, dropoffLng, settings);
}
