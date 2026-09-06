import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
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
  String? token;

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

  Future<Map<String, dynamic>> sendPhoneOtp(String phoneNumber) async {
    isLoading = true;
    notifyListeners();
    try {
      return await api.sendPhoneOtp(phoneNumber);
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
        notifyListeners();
      },
      onRideStatusChanged: (statusData) {
        tripStatus = statusData['status'];
        notifyListeners();
      },
      onRideFinished: (finished) {
        tripStatus = 'COMPLETED';
        finalFarePaid = finished['finalFareNgn'];
        notifyListeners();
      },
    );
  }

  Future<void> calculateEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      currentEstimate = await api.getEstimate(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
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
      preferQuiet = prefs.getBool('pref_prefer_quiet') ?? false;
      alwaysAcOn = prefs.getBool('pref_always_ac_on') ?? true;
      luggageAssistance = prefs.getBool('pref_luggage_assistance') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPreference(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_$key', val);
      if (key == 'prefer_quiet') preferQuiet = val;
      if (key == 'always_ac_on') alwaysAcOn = val;
      if (key == 'luggage_assistance') luggageAssistance = val;
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
