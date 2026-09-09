import { Router, Request, Response } from 'express';
import axios from 'axios';

export const placesRouter = Router();

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyBocaieybQzVpYXhPtXGkU1y88QIQMdfyg';

// In-memory cache for repeated search queries (10 minute TTL)
const queryCache = new Map<string, { timestamp: number; data: any[] }>();
const CACHE_TTL_MS = 10 * 60 * 1000;

placesRouter.get('/search', async (req: Request, res: Response) => {
  const query = (req.query.query as string || '').trim();
  if (!query || query.length < 2) {
    return res.status(200).json({ success: true, data: [] });
  }

  const lat = parseFloat(req.query.lat as string) || 6.5244;
  const lng = parseFloat(req.query.lng as string) || 3.3792;
  const isInterstate = req.query.isInterstate === 'true';

  const cacheKey = 'search_' + query.toLowerCase() + '_' + (isInterstate ? 'inter' : 'local') + '_' + lat.toFixed(2) + '_' + lng.toFixed(2);
  const cached = queryCache.get(cacheKey);
  if (cached && (Date.now() - cached.timestamp < CACHE_TTL_MS)) {
    return res.status(200).json({ success: true, source: 'cache', data: cached.data });
  }

  try {
    const googleUrl = 'https://places.googleapis.com/v1/places:searchText';
    
    // Google Places API (New) strictly requires radius to be <= 50000 meters
    const body: Record<string, any> = {
      textQuery: query,
    };

    if (!isInterstate) {
      body.locationBias = {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: 45000.0,
        },
      };
    }

    const response = await axios.post(googleUrl, body, {
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_API_KEY,
        'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location',
      },
      timeout: 5000,
    });

    const rawPlaces = response.data.places || [];
    const formatted = rawPlaces.map((p: any) => ({
      title: p.displayName?.text || '',
      subtitle: p.formattedAddress || 'Nigeria',
      latitude: p.location?.latitude || lat,
      longitude: p.location?.longitude || lng,
    })).filter((p: any) => p.title.length > 0);

    queryCache.set(cacheKey, { timestamp: Date.now(), data: formatted });

    return res.status(200).json({
      success: true,
      source: 'google_places_new',
      data: formatted,
    });
  } catch (err: any) {
    console.error('[Places Search Error]', err.response?.data || err.message);
    
    // Fallback: Google Geocoding API
    try {
      const geoUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=' + encodeURIComponent(query + ', Nigeria') + '&key=' + GOOGLE_API_KEY;
      const geoResp = await axios.get(geoUrl, { timeout: 4000 });
      if (geoResp.data.status === 'OK') {
        const results = (geoResp.data.results || []).map((r: any) => ({
          title: r.address_components?.[0]?.long_name || r.formatted_address,
          subtitle: r.formatted_address,
          latitude: r.geometry?.location?.lat || lat,
          longitude: r.geometry?.location?.lng || lng,
        }));
        return res.status(200).json({ success: true, source: 'google_geocoding_fallback', data: results });
      }
    } catch (_) {}

    return res.status(200).json({ success: true, data: [] });
  }
});

placesRouter.get('/autocomplete', async (req: Request, res: Response) => {
  const input = (req.query.input as string || req.query.query as string || '').trim();
  if (!input || input.length < 2) {
    return res.status(200).json({ success: true, data: [] });
  }

  const lat = parseFloat(req.query.lat as string) || 6.5244;
  const lng = parseFloat(req.query.lng as string) || 3.3792;

  try {
    const autoUrl = 'https://places.googleapis.com/v1/places:autocomplete';
    const response = await axios.post(autoUrl, {
      input,
      includedRegionCodes: ['ng'],
      locationBias: {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: 45000.0,
        },
      },
    }, {
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_API_KEY,
      },
      timeout: 4000,
    });

    const suggestions = (response.data.suggestions || []).map((s: any) => {
      const pred = s.placePrediction;
      return {
        title: pred?.text?.text || pred?.structuredFormat?.mainText?.text || '',
        subtitle: pred?.structuredFormat?.secondaryText?.text || 'Nigeria',
        placeId: pred?.placeId,
      };
    }).filter((s: any) => s.title.length > 0);

    return res.status(200).json({
      success: true,
      source: 'google_places_autocomplete',
      data: suggestions,
    });
  } catch (err: any) {
    console.error('[Places Autocomplete Error]', err.response?.data || err.message);
    return res.status(200).json({ success: true, data: [] });
  }
});
