/**
 * Geospatial utility functions for calculating distances and travel times.
 */

// Earth radius in kilometers
const EARTH_RADIUS_KM = 6371.0;

/**
 * Calculates the great-circle distance between two points in kilometers using Haversine formula.
 */
export function calculateHaversineDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = EARTH_RADIUS_KM * c;

  return Math.round(distance * 100) / 100; // Round to 2 decimal places
}

/**
 * Converts degrees to radians.
 */
function toRad(degrees: number): number {
  return (degrees * Math.PI) / 180.0;
}

/**
 * Estimates travel time in minutes based on distance and average Nigerian urban traffic speed.
 * Default average urban speed in Lagos/Abuja is approximately 25-30 km/h during daytime.
 */
export function estimateTravelTimeMinutes(
  distanceKm: number,
  trafficFactor: number = 1.0
): number {
  const averageSpeedKmH = 26.0 / trafficFactor;
  const hours = distanceKm / averageSpeedKmH;
  const minutes = Math.max(5, Math.round(hours * 60)); // Minimum 5 minutes
  return minutes;
}
