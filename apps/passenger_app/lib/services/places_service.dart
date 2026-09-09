import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng location;

  PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.location,
  });
}

class PlacesService {
  /// Comprehensive offline-cached Nigerian landmarks & transit nodes
  static final List<Map<String, dynamic>> _curatedLandmarks = [
    // --- IBADAN ---
    {'name': 'University of Ibadan (UI Main Gate)', 'city': 'Ibadan, Oyo', 'lat': 7.4443, 'lng': 3.8997, 'tags': 'ui university ibadan agbowo sango'},
    {'name': 'Bodija Market & Housing Estate', 'city': 'Ibadan, Oyo', 'lat': 7.4350, 'lng': 3.9080, 'tags': 'bodija market housing estate old bodija'},
    {'name': 'Dugbe Commercial Hub & Cocoa House', 'city': 'Ibadan, Oyo', 'lat': 7.3872, 'lng': 3.8760, 'tags': 'dugbe cocoa house gbagi lebanon street bank road'},
    {'name': 'Challenge Bus Stop & Terminal', 'city': 'Ibadan, Oyo', 'lat': 7.3480, 'lng': 3.8720, 'tags': 'challenge toll gate molete odo ona feeder'},
    {'name': 'Iwo Road Interchange & Motor Park', 'city': 'Ibadan, Oyo', 'lat': 7.4120, 'lng': 3.9350, 'tags': 'iwo road expressway round about motor park'},
    {'name': 'The Palms Mall (Shoprite Ring Road)', 'city': 'Ibadan, Oyo', 'lat': 7.3610, 'lng': 3.8680, 'tags': 'palms mall shoprite ring road mko abiola way'},
    {'name': 'Ventura Mall & Cinema, Samonda', 'city': 'Ibadan, Oyo', 'lat': 7.4330, 'lng': 3.8940, 'tags': 'ventura mall samonda sango ui road arcade cinema'},
    {'name': 'University College Hospital (UCH)', 'city': 'Ibadan, Oyo', 'lat': 7.4040, 'lng': 3.9050, 'tags': 'uch hospital queen elizabeth agodi total garden'},
    {'name': 'Mokola Roundabout & Flyover', 'city': 'Ibadan, Oyo', 'lat': 7.4080, 'lng': 3.8860, 'tags': 'mokola veterinary sabo cultural centre hill'},
    {'name': 'Oyo State Government Secretariat, Agodi', 'city': 'Ibadan, Oyo', 'lat': 7.4170, 'lng': 3.9050, 'tags': 'secretariat agodi governor office parliament'},
    {'name': 'Lead City University, Toll Gate', 'city': 'Ibadan, Oyo', 'lat': 7.3190, 'lng': 3.8710, 'tags': 'lead city university toll gate ibadan expressway'},
    {'name': 'The Polytechnic Ibadan (Sango)', 'city': 'Ibadan, Oyo', 'lat': 7.4420, 'lng': 3.8790, 'tags': 'polytechnic sango apete ijokodo poly'},
    {'name': 'Jericho GRA & Golf Club', 'city': 'Ibadan, Oyo', 'lat': 7.3880, 'lng': 3.8600, 'tags': 'jericho gra onireke golf club nihort'},
    {'name': 'Oluyole Industrial Estate', 'city': 'Ibadan, Oyo', 'lat': 7.3510, 'lng': 3.8560, 'tags': 'oluyole estate industrial 7up anchor'},
    {'name': 'Eleyele Junction & Water Works', 'city': 'Ibadan, Oyo', 'lat': 7.4210, 'lng': 3.8640, 'tags': 'eleyele barracks water works junction ologuneru'},
    {'name': 'Apata & NNPC Mega Station', 'city': 'Ibadan, Oyo', 'lat': 7.3620, 'lng': 3.8210, 'tags': 'apata nnpc mega station bembo abebe'},
    {'name': 'Ojoo Bus Terminal', 'city': 'Ibadan, Oyo', 'lat': 7.4680, 'lng': 3.9140, 'tags': 'ojoo terminal barrack ajibode moniya'},
    {'name': 'Alakia Ibadan Airport', 'city': 'Ibadan, Oyo', 'lat': 7.3620, 'lng': 3.9780, 'tags': 'airport alakia gbongan road airway'},
    {'name': 'Akobo Oju Irin', 'city': 'Ibadan, Oyo', 'lat': 7.4480, 'lng': 3.9510, 'tags': 'akobo general gas ojurin ojurin alegongo'},
    {'name': 'New Garage Motor Park', 'city': 'Ibadan, Oyo', 'lat': 7.3240, 'lng': 3.8700, 'tags': 'new garage paseda lagos express'},

    // --- LAGOS ---
    {'name': 'Murtala Muhammed International Airport (MMIA)', 'city': 'Ikeja, Lagos', 'lat': 6.5774, 'lng': 3.3211, 'tags': 'airport mmia mma2 domestic international ikeja'},
    {'name': 'Ikeja City Mall (ICM)', 'city': 'Alausa, Ikeja, Lagos', 'lat': 6.6173, 'lng': 3.3580, 'tags': 'icm ikeja city mall alausa shoprite cinema governor office'},
    {'name': 'Lekki Phase 1 (Admiralty Way)', 'city': 'Lekki, Lagos', 'lat': 6.4474, 'lng': 3.4731, 'tags': 'lekki phase 1 admiralty way toll gate fola osibo'},
    {'name': 'Victoria Island (Eko Hotel & Suites)', 'city': 'Victoria Island, Lagos', 'lat': 6.4281, 'lng': 3.4219, 'tags': 'victoria island vi eko hotel adetokunbo ademola bar beach'},
    {'name': 'Chevron Toll Gate', 'city': 'Lekki-Epe Express, Lagos', 'lat': 6.4380, 'lng': 3.5350, 'tags': 'chevron toll gate conservation center drive orchid'},
    {'name': 'Ajah Jubilee Bridge & Market', 'city': 'Ajah, Lagos', 'lat': 6.4680, 'lng': 3.5680, 'tags': 'ajah jubilee bridge market badore addo ajiwe'},
    {'name': 'Novare Mall (Shoprite Sangotedo)', 'city': 'Sangotedo, Lagos', 'lat': 6.4740, 'lng': 3.6260, 'tags': 'novare mall sangotedo shoprite monastery abijo'},
    {'name': 'Yaba (Commercial Ave / Sabo Market)', 'city': 'Yaba, Lagos', 'lat': 6.5180, 'lng': 3.3790, 'tags': 'yaba sabo market yabatech tejuosho herbert macaulay'},
    {'name': 'University of Lagos (UNILAG Main Gate)', 'city': 'Akoka, Lagos', 'lat': 6.5180, 'lng': 3.3980, 'tags': 'unilag akoka gate university lagos moremi'},
    {'name': 'Surulere (National Stadium / Ojuelegba)', 'city': 'Surulere, Lagos', 'lat': 6.4980, 'lng': 3.3580, 'tags': 'surulere national stadium ojuelegba bode thomas adeniran ogunsanya'},
    {'name': 'Maryland Mall (The Black Box)', 'city': 'Maryland, Lagos', 'lat': 6.5720, 'lng': 3.3670, 'tags': 'maryland mall black box ikorodu road anthony cane'},
    {'name': 'Berger Bus Stop (Lagos-Ibadan Gate)', 'city': 'Ojodu Berger, Lagos', 'lat': 6.6480, 'lng': 3.3710, 'tags': 'berger bus stop ojodu lagos ibadan expressway gate'},
    {'name': 'Oshodi Transport Interchange', 'city': 'Oshodi, Lagos', 'lat': 6.5450, 'lng': 3.3520, 'tags': 'oshodi transport interchange terminal 1 2 3 bus'},
    {'name': 'Festac Town (1st Gate / 21 Road)', 'city': 'Festac, Lagos', 'lat': 6.4620, 'lng': 3.2840, 'tags': 'festac town 1st gate 21 road 7th avenue amuwo odofin'},

    // --- ABUJA ---
    {'name': 'Nnamdi Azikiwe International Airport', 'city': 'Airport Road, Abuja', 'lat': 9.0065, 'lng': 7.2631, 'tags': 'airport abuja international domestic luggage'},
    {'name': 'Wuse 2 (Banex Plaza / Aminu Kano)', 'city': 'Wuse 2, Abuja', 'lat': 9.0765, 'lng': 7.4722, 'tags': 'wuse 2 banex plaza aminu kano crescent wuse market'},
    {'name': 'Maitama (Transcorp Hilton)', 'city': 'Maitama, Abuja', 'lat': 9.0820, 'lng': 7.4980, 'tags': 'maitama transcorp hilton aguiyi ironsi minister hill'},
    {'name': 'Jabi Lake Mall', 'city': 'Jabi, Abuja', 'lat': 9.0760, 'lng': 7.4260, 'tags': 'jabi lake mall shoprite lake water boat'},
    {'name': 'Central Business District (Federal Secretariat)', 'city': 'CBD, Abuja', 'lat': 9.0580, 'lng': 7.4890, 'tags': 'cbd federal secretariat shehu shagari national mosque church'},
    {'name': 'Gwarinpa Estate (1st Ave / 3rd Ave)', 'city': 'Gwarinpa, Abuja', 'lat': 9.1120, 'lng': 7.4080, 'tags': 'gwarinpa estate 1st 2nd 3rd 4th avenue charly boy'},
    {'name': 'Kubwa (Dutse Junction / NYSC Camp)', 'city': 'Kubwa, Abuja', 'lat': 9.1550, 'lng': 7.3380, 'tags': 'kubwa dutse junction pw nysc orientation camp'},

    // --- PORT HARCOURT ---
    {'name': 'Port Harcourt International Airport', 'city': 'Omagwa, Rivers', 'lat': 4.9810, 'lng': 6.9490, 'tags': 'port harcourt airport omagwa rivers state'},
    {'name': 'GRA Phase 2 (Tombia Street)', 'city': 'GRA, Port Harcourt', 'lat': 4.8180, 'lng': 6.9980, 'tags': 'gra phase 2 tombia street polo club genesis'},
    {'name': 'Peter Odili Road', 'city': 'Trans Amadi, Port Harcourt', 'lat': 4.8120, 'lng': 7.0380, 'tags': 'peter odili road trans amadi industrial slaughter'},
    {'name': 'Pleasure Park (Aba Road)', 'city': 'Aba Road, Port Harcourt', 'lat': 4.8340, 'lng': 7.0150, 'tags': 'pleasure park aba road bori camp airforce base'},
  ];

  /// Fast, pinpoint landmark and estate search with 3-tier fallback:
  /// 1. Instant Curated Local Landmarks (0ms)
  /// 2. Mapbox Forward Geocoding
  /// 3. OpenStreetMap Nominatim with Nigerian Boundaries
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
    bool isInterstate = false,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final center = proximity ?? const LatLng(7.3775, 3.9470); // Default to live center
    final lowerQuery = cleanQuery.toLowerCase();
    final List<PlaceSuggestion> results = [];
    final Set<String> seenKeys = {};
    const distanceCalc = Distance();

    // 1. Instant 0ms Match from Curated Nigerian Landmarks
    for (final lm in _curatedLandmarks) {
      final name = lm['name'] as String;
      final tags = lm['tags'] as String;
      final city = lm['city'] as String;

      if (name.toLowerCase().contains(lowerQuery) || tags.contains(lowerQuery) || city.toLowerCase().contains(lowerQuery)) {
        final loc = LatLng(lm['lat'] as double, lm['lng'] as double);

        if (!isInterstate) {
          final distKm = distanceCalc.as(LengthUnit.Kilometer, center, loc);
          if (distKm > 65.0) continue; // Skip landmarks in distant states during local city rides
        }

        final key = '${loc.latitude.toStringAsFixed(3)},${loc.longitude.toStringAsFixed(3)}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          results.add(PlaceSuggestion(
            title: name,
            subtitle: city,
            location: loc,
          ));
        }
      }
    }

    // 2. Mapbox Places Search
    try {
      final encodedQuery = Uri.encodeComponent(cleanQuery);
      final token = AppConstants.mapboxPublicToken;

      String bboxParam = '';
      if (!isInterstate) {
        const double delta = 0.50; // ~55 km radius
        final minLng = (center.longitude - delta).toStringAsFixed(4);
        final minLat = (center.latitude - delta).toStringAsFixed(4);
        final maxLng = (center.longitude + delta).toStringAsFixed(4);
        final maxLat = (center.latitude + delta).toStringAsFixed(4);
        bboxParam = '&bbox=$minLng,$minLat,$maxLng,$maxLat';
      }

      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?country=ng'
        '$bboxParam'
        '&proximity=${center.longitude},${center.latitude}'
        '&limit=10'
        '&access_token=$token',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        for (final feat in features) {
          final title = (feat['text'] ?? feat['place_name'] ?? 'Location').toString();
          final fullName = (feat['place_name'] ?? '').toString();

          String subtitle = fullName;
          if (fullName.startsWith(title) && fullName.length > title.length) {
            subtitle = fullName.substring(title.length).replaceFirst(RegExp(r'^,\s*'), '');
          }
          if (subtitle.isEmpty) subtitle = 'Nigeria';

          final centerCoords = feat['center'] as List<dynamic>? ?? [center.longitude, center.latitude];
          final lng = (centerCoords[0] as num).toDouble();
          final lat = (centerCoords[1] as num).toDouble();
          final loc = LatLng(lat, lng);

          if (!isInterstate) {
            final distKm = distanceCalc.as(LengthUnit.Kilometer, center, loc);
            if (distKm > 65.0) continue;
          }

          final key = '${loc.latitude.toStringAsFixed(3)},${loc.longitude.toStringAsFixed(3)}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            results.add(PlaceSuggestion(
              title: title,
              subtitle: subtitle,
              location: loc,
            ));
          }
        }
      }
    } catch (_) {}

    // 3. OpenStreetMap Nominatim Fallback (Deep local coverage for Nigerian streets, gates, markets)
    if (results.length < 4) {
      try {
        final encodedQuery = Uri.encodeComponent(cleanQuery);
        final osmUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery'
          '&format=json'
          '&countrycodes=ng'
          '&addressdetails=1'
          '&limit=8',
        );

        final osmResp = await http.get(
          osmUrl,
          headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
        ).timeout(const Duration(seconds: 4));

        if (osmResp.statusCode == 200) {
          final List<dynamic> osmList = jsonDecode(osmResp.body) as List<dynamic>? ?? [];

          for (final item in osmList) {
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            if (lat == 0.0 || lon == 0.0) continue;

            final loc = LatLng(lat, lon);

            if (!isInterstate) {
              final distKm = distanceCalc.as(LengthUnit.Kilometer, center, loc);
              if (distKm > 65.0) continue;
            }

            final displayName = (item['display_name'] ?? '').toString();
            final parts = displayName.split(',');
            final title = parts.isNotEmpty ? parts[0].trim() : 'Location';
            final subtitle = parts.length > 1 ? parts.sublist(1, parts.length > 3 ? 3 : parts.length).join(',').trim() : 'Nigeria';

            final key = '${loc.latitude.toStringAsFixed(3)},${loc.longitude.toStringAsFixed(3)}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              results.add(PlaceSuggestion(
                title: title,
                subtitle: subtitle,
                location: loc,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Sort all results by proximity so closest destinations to the user appear first!
    results.sort((a, b) {
      final distA = distanceCalc.as(LengthUnit.Kilometer, center, a.location);
      final distB = distanceCalc.as(LengthUnit.Kilometer, center, b.location);
      return distA.compareTo(distB);
    });

    return results;
  }

  /// Reverse geocode LatLng to readable Nigerian street/estate name via Mapbox
  static Future<String> reverseGeocode(LatLng location) async {
    final token = AppConstants.mapboxPublicToken;
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json'
      '?country=ng'
      '&types=address,poi,neighborhood,locality'
      '&limit=1'
      '&access_token=$token',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final top = features[0];
          final placeName = (top['place_name'] ?? top['text'] ?? '').toString();
          if (placeName.isNotEmpty) {
            return placeName;
          }
        }
      }
    } catch (_) {}

    return 'Current Location';
  }
}
