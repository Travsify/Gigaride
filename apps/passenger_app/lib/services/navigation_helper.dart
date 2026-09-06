import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

class NavigationHelper {
  /// 1-Tap Zero-Burn Navigation Handoff
  /// Launches native Google Maps / Waze / Apple Maps on device with turn-by-turn driving mode.
  /// Zero developer API cost!
  static Future<bool> launchExternalNavigation({
    required LatLng destination,
    String? destinationLabel,
  }) async {
    final lat = destination.latitude;
    final lng = destination.longitude;

    // 1. Try google.navigation intent (Native Android Google Maps Turn-by-Turn)
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(googleNavUri)) {
      await launchUrl(googleNavUri);
      return true;
    }

    // 2. Try geo uri (Universal maps handler: Google Maps, Waze, etc.)
    final label = Uri.encodeComponent(destinationLabel ?? 'Destination');
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return true;
    }

    // 3. Fallback: Google Maps web / browser directions link
    final webMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(webMapsUri)) {
      await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      return true;
    }

    return false;
  }
}
