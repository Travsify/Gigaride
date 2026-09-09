import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/places_service.dart';
import '../services/socket_service.dart';

class PassengerProvider with ChangeNotifier {
  final ApiService api = ApiService();
  final SocketService socket = SocketService();

  bool isLoading = false;
  Map<String, dynamic>? user;

  // Active Booking state
  Map<String, dynamic>? currentEstimate;
  Map<String, dynamic>? currentRide;
  List<Map<String, dynamic>> incomingBids = [];
  Map<String, dynamic>? selectedDriverBid;
  String? tripStatus; // 'ACCEPTED', 'ARRIVED', 'IN_TRANSIT', 'COMPLETED'
  int? finalFarePaid;

  // 🚗 Live Real-Time Telemetry & Environs Awareness
  LatLng? liveDriverLocation;
  double liveDriverHeading = 0.0;
  double liveDriverSpeed = 0.0;
  String? activeMilestoneMessage;
  String? nearestLandmarkName;
  int freeWaitSecondsRemaining = 180;
  Timer? _waitCountdownTimer;

  // Real Ride History & Scheduled Trips from backend
  List<dynamic> pastRides = [];
  List<dynamic> scheduledTrips = [];
  bool isLoadingHistory = false;

  // Saved Places (Persistent Home & Work Bookmarks)
  Map<String, String> savedPlaces = {'Home': '', 'Work': ''};

  // Emergency SOS Contacts
  List<Map<String, String>> emergencyContacts = [];

  // Ride Comfort Preferences
  bool preferQuiet = false;
  bool alwaysAcOn = true;
  bool luggageAssistance = false;
  bool petFriendly = false;
  bool accessibilitySupport = false;
  bool noMusic = false;
  String? token;

  int get walletBalance {
    final bal = vba?['balance_ngn'] ?? user?['walletBalance'] ?? user?['wallet_balance'] ?? 0;
    if (bal is num) return bal.toInt();
    if (bal is String) return int.tryParse(bal) ?? 0;
    return 0;
  }

  Future<bool> checkAuth() async {
    final t = await api.getToken();
    if (t == null) return false;
    token = t;
    try {
      final profile = await api.getMe();
      user = profile;
      connectSocket(t);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> sendPhoneOtp(String phoneNumber, {bool isSignUp = false, bool isLogin = false}) async {
    isLoading = true;
    notifyListeners();
    try {
      return await api.sendPhoneOtp(phoneNumber, isSignUp: isSignUp, isLogin: isLogin);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp(String phoneNumber, String otpCode) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.verifyPhoneOtp(phoneNumber, otpCode);
      if (res['token'] != null && res['user'] != null) {
        token = res['token'];
        user = res['user'];
        if (user?['id'] != null) {
          OneSignal.login(user!['id']);
        }
        connectSocket(res['token']);
      }
      return res;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    isLoading = true;
    notifyListeners();
    try {
      return await api.sendEmailOtp(email);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyEmailOtp(String email, String otpCode) async {
    isLoading = true;
    notifyListeners();
    try {
      return await api.verifyEmailOtp(email, otpCode);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> checkAvailability({String? phoneNumber, String? email}) async {
    return await api.checkAvailability(phoneNumber: phoneNumber, email: email);
  }

  Future<Map<String, dynamic>> sendEmailLoginOtp(String email) async {
    isLoading = true;
    notifyListeners();
    try {
      return await api.sendEmailLoginOtp(email);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithEmailOtp(String email, String otpCode) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.loginWithEmailOtp(email, otpCode);
      token = res['token'];
      user = res['user'];
      if (user?['id'] != null) {
        OneSignal.login(user!['id']);
      }
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle({
    required String email,
    String? fullName,
    String? googleId,
    String? photoUrl,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.loginWithGoogle(
        email: email,
        fullName: fullName,
        googleId: googleId,
        photoUrl: photoUrl,
      );
      token = res['token'];
      user = res['user'];
      if (user?['id'] != null) {
        OneSignal.login(user!['id']);
      }
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }



  Future<void> login(String identifier, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.login(identifier, password);
      token = res['token'];
      user = res['user'];
      if (user?['id'] != null) {
        OneSignal.login(user!['id']);
      }
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String fullName, String phone, String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.registerPassenger(
        fullName: fullName,
        phoneNumber: phone,
        email: email,
        password: password,
      );
      token = res['token'];
      user = res['user'];
      if (user?['id'] != null) {
        OneSignal.login(user!['id']);
      }
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void connectSocket(String token) {
    socket.connect(
      token,
      onNewDriverBid: (bid) {
        // Prevent duplicate bids from same driver
        incomingBids.removeWhere((b) => b['driverId'] == bid['driverId']);
        incomingBids.insert(0, bid);
        HapticFeedback.lightImpact();
        notifyListeners();
      },
      onRideStatusChanged: (statusData) {
        final newStatus = statusData['status'];
        tripStatus = newStatus;

        if (newStatus == 'ARRIVED') {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.alert);
          activeMilestoneMessage = 'Driver has arrived outside! Free wait: 03:00';
          _startFreeWaitTimer();
        } else if (newStatus == 'IN_TRANSIT') {
          _waitCountdownTimer?.cancel();
          HapticFeedback.mediumImpact();
          activeMilestoneMessage = 'Trip in progress • Heading to destination';
        } else if (newStatus == 'COMPLETED') {
          _waitCountdownTimer?.cancel();
          HapticFeedback.heavyImpact();
          activeMilestoneMessage = 'Trip completed! Please rate your ride';
        }

        notifyListeners();
      },
      onRideFinished: (finished) {
        tripStatus = 'COMPLETED';
        finalFarePaid = finished['finalFareNgn'];
        _waitCountdownTimer?.cancel();
        HapticFeedback.heavyImpact();
        notifyListeners();
      },
    );

    // 🚗 Live Driver GPS Telemetry & Landmark Snapping
    socket.onDriverLocationUpdate = (locData) {
      final lat = (locData['latitude'] as num?)?.toDouble();
      final lng = (locData['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        liveDriverLocation = LatLng(lat, lng);
        liveDriverHeading = (locData['heading'] as num?)?.toDouble() ?? liveDriverHeading;
        liveDriverSpeed = (locData['speedKmh'] as num?)?.toDouble() ?? 0.0;

        // Check if passing near any iconic Nigerian landmark
        final nearest = PlacesService.findNearestLandmark(liveDriverLocation!, maxDistanceKm: 0.45);
        if (nearest != null) {
          nearestLandmarkName = nearest['name'];
        }

        if (tripStatus == 'ACCEPTED') {
          if (nearestLandmarkName != null) {
            activeMilestoneMessage = 'Driver on the way • Passing $nearestLandmarkName';
          } else {
            activeMilestoneMessage = 'Driver is on the way to pickup';
          }
        } else if (tripStatus == 'IN_TRANSIT') {
          if (nearestLandmarkName != null) {
            activeMilestoneMessage = 'En route to destination • Passing $nearestLandmarkName';
          } else {
            activeMilestoneMessage = 'Trip in progress • Heading to destination';
          }
        }
        notifyListeners();
      }
    };

    // ⚡ Driver Approaching Notification (< 500m)
    socket.onDriverApproaching = (data) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
      activeMilestoneMessage = 'Driver is ~2 mins away! Please head outside to pickup.';
      notifyListeners();
    };

    // 🚫 Ride Cancelled Listener
    socket.onRideCancelled = (data) {
      tripStatus = 'CANCELLED';
      _waitCountdownTimer?.cancel();
      activeMilestoneMessage = 'Ride was cancelled: ${data['reason'] ?? 'Driver/Passenger cancelled'}';
      HapticFeedback.heavyImpact();
      notifyListeners();
    };

    // 💵 Wallet Change Credited
    socket.onWalletChangeCredited = (data) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      notifyListeners();
    };
  }

  void cancelActiveRide({String? reason}) {
    if (currentRide != null) {
      socket.cancelRide(rideId: currentRide!['id'], reason: reason);
      tripStatus = 'CANCELLED';
      _waitCountdownTimer?.cancel();
      notifyListeners();
    }
  }

  void reportInTripIssue({required String issueType, required String description}) {
    if (currentRide != null) {
      socket.reportRideIssue(
        rideId: currentRide!['id'],
        issueType: issueType,
        description: description,
      );
    }
  }

  void settleCashChange({required int tenderedNgn, required int agreedFareNgn}) {
    if (currentRide != null) {
      socket.settleChangeToWallet(
        rideId: currentRide!['id'],
        tenderedNgn: tenderedNgn,
        agreedFareNgn: agreedFareNgn,
      );
    }
  }

  void _startFreeWaitTimer() {
    _waitCountdownTimer?.cancel();
    freeWaitSecondsRemaining = 180;
    _waitCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (freeWaitSecondsRemaining > 0) {
        freeWaitSecondsRemaining--;
        final mins = (freeWaitSecondsRemaining ~/ 60).toString().padLeft(2, '0');
        final secs = (freeWaitSecondsRemaining % 60).toString().padLeft(2, '0');
        activeMilestoneMessage = 'Driver waiting outside • Free wait: $mins:$secs';
        notifyListeners();
      } else {
        activeMilestoneMessage = 'Driver waiting outside • Standard wait rate applies';
        timer.cancel();
        notifyListeners();
      }
    });
  }

  Future<void> calculateEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? distanceKm,
    int? durationMinutes,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      currentEstimate = await api.getEstimate(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitRideRequest({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required int riderOfferNgn,
    String? notes,
    bool isBusiness = false,
    String? riderName,
    String? riderPhone,
    String? riderType,
    double? distanceKm,
    int? durationMinutes,
  }) async {
    isLoading = true;
    incomingBids.clear();
    selectedDriverBid = null;
    tripStatus = null;
    notifyListeners();
    try {
      currentRide = await api.createRideRequest(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupAddress: pickupAddress,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        dropoffAddress: dropoffAddress,
        riderOfferNgn: riderOfferNgn,
        notes: notes,
        isBusiness: isBusiness,
        riderName: riderName,
        riderPhone: riderPhone,
        riderType: riderType,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );

      // Broadcast ride request to nearby drivers via Socket.io
      socket.broadcastRide(currentRide!['id']);
      tripStatus = 'NEGOTIATING';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void acceptDriverBid(Map<String, dynamic> bid) {
    if (currentRide == null) return;
    selectedDriverBid = bid;
    tripStatus = 'ACCEPTED';
    socket.acceptBid(
      rideId: currentRide!['id'],
      driverId: bid['driverId'],
      agreedFareNgn: bid['counterFareNgn'],
    );
    notifyListeners();
  }

  void resetTrip() {
    currentRide = null;
    currentEstimate = null;
    incomingBids.clear();
    selectedDriverBid = null;
    tripStatus = null;
    finalFarePaid = null;
    notifyListeners();
  }

  // Trigger Emergency SOS alert
  void triggerEmergencySos({double? lat, double? lng, String? notes}) {
    if (currentRide == null) return;
    socket.triggerSos(
      rideId: currentRide!['id'],
      latitude: lat ?? 6.5244,
      longitude: lng ?? 3.3792,
      notes: notes ?? 'Emergency SOS triggered by passenger in mobile app',
    );
  }

  // Pay for ride using Giga Living Wallet
  Future<Map<String, dynamic>> payWithLivingWallet() async {
    if (currentRide == null) throw Exception('No active ride to settle');
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.payRideWithWallet(currentRide!['id']);
      finalFarePaid = res['fareNgn'];
      return res;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Schedule advance airport or interstate trip
  Future<Map<String, dynamic>> scheduleAdvanceTrip({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String scheduledFor,
    required int riderOfferNgn,
    String? flightNumber,
    bool isAirport = false,
    bool isInterstate = false,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      return await api.scheduleRide(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupAddress: pickupAddress,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        dropoffAddress: dropoffAddress,
        scheduledFor: scheduledFor,
        riderOfferNgn: riderOfferNgn,
        flightNumber: flightNumber,
        isAirport: isAirport,
        isInterstate: isInterstate,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Load real ride history & scheduled trips from backend API
  Future<void> loadRiderHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      final list = await api.getRiderHistory();
      pastRides = list.where((r) => r['is_scheduled'] != true && r['status'] == 'COMPLETED').toList();
      scheduledTrips = list.where((r) => r['is_scheduled'] == true || r['scheduled_for'] != null).toList();

      // Detect and restore any active ride in progress
      final activeList = list.where((r) => ['REQUESTED', 'NEGOTIATING', 'ACCEPTED', 'ARRIVED', 'IN_TRANSIT'].contains(r['status'])).toList();
      if (activeList.isNotEmpty) {
        final active = activeList.first;
        currentRide = active;
        tripStatus = active['status'];
        if (active['driver'] != null) {
          selectedDriverBid = {
            'driverName': active['driver']['full_name'] ?? 'Driver',
            'driverPhone': active['driver']['phone_number'] ?? '',
            'vehicleModel': active['driverProfile']?['vehicle_model'] ?? 'Verified Vehicle',
            'vehicleMake': active['driverProfile']?['vehicle_make'] ?? '',
            'vehicleColor': active['driverProfile']?['vehicle_color'] ?? '',
            'licensePlate': active['driverProfile']?['license_plate'] ?? '',
            'rating': active['driverProfile']?['rating_average'] ?? 4.9,
            'counterFareNgn': active['agreed_fare_ngn'] ?? active['rider_offer_ngn'],
            'rideId': active['id'],
          };
        }
      }
    } catch (_) {
      // Graceful fallback to avoid app interruption
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  // Load Saved Places from persistent local storage
  Future<void> loadSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      savedPlaces = {
        'Home': prefs.getString('saved_place_home') ?? '',
        'Work': prefs.getString('saved_place_work') ?? '',
      };
      notifyListeners();
    } catch (_) {}
  }

  Future<void> savePlace(String label, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_place_${label.toLowerCase()}', address);
      savedPlaces[label] = address;
      notifyListeners();
    } catch (_) {}
  }

  // Load Emergency SOS Contacts
  Future<void> loadEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('emergency_contacts_json');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        emergencyContacts = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addEmergencyContact(String name, String phone) async {
    try {
      emergencyContacts.add({'name': name, 'phone': phone});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergency_contacts_json', jsonEncode(emergencyContacts));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeEmergencyContact(int index) async {
    try {
      if (index >= 0 && index < emergencyContacts.length) {
        emergencyContacts.removeAt(index);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('emergency_contacts_json', jsonEncode(emergencyContacts));
        notifyListeners();
      }
    } catch (_) {}
  }

  // Load Rider Comfort Preferences
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      preferQuiet = prefs.getBool('pref_prefer_quiet') ?? prefs.getBool('pref_preferQuiet') ?? false;
      alwaysAcOn = prefs.getBool('pref_always_ac_on') ?? prefs.getBool('pref_alwaysAcOn') ?? true;
      luggageAssistance = prefs.getBool('pref_luggage_assistance') ?? prefs.getBool('pref_luggageAssistance') ?? false;
      petFriendly = prefs.getBool('pref_pet_friendly') ?? prefs.getBool('pref_petFriendly') ?? false;
      accessibilitySupport = prefs.getBool('pref_accessibility_support') ?? prefs.getBool('pref_accessibilitySupport') ?? false;
      noMusic = prefs.getBool('pref_no_music') ?? prefs.getBool('pref_noMusic') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPreference(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_$key', val);
      final normalizedKey = key.replaceAll('_', '').toLowerCase();

      if (normalizedKey == 'preferquiet') {
        preferQuiet = val;
        await prefs.setBool('pref_prefer_quiet', val);
        await prefs.setBool('pref_preferQuiet', val);
      } else if (normalizedKey == 'alwaysacon') {
        alwaysAcOn = val;
        await prefs.setBool('pref_always_ac_on', val);
        await prefs.setBool('pref_alwaysAcOn', val);
      } else if (normalizedKey == 'luggageassistance') {
        luggageAssistance = val;
        await prefs.setBool('pref_luggage_assistance', val);
        await prefs.setBool('pref_luggageAssistance', val);
      } else if (normalizedKey == 'petfriendly') {
        petFriendly = val;
        await prefs.setBool('pref_pet_friendly', val);
        await prefs.setBool('pref_petFriendly', val);
      } else if (normalizedKey == 'accessibilitysupport') {
        accessibilitySupport = val;
        await prefs.setBool('pref_accessibility_support', val);
        await prefs.setBool('pref_accessibilitySupport', val);
      } else if (normalizedKey == 'nomusic') {
        noMusic = val;
        await prefs.setBool('pref_no_music', val);
        await prefs.setBool('pref_noMusic', val);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    OneSignal.logout();
    await api.clearAuth();
    socket.disconnect();
    user = null;
    resetTrip();
    notifyListeners();
  }
}
