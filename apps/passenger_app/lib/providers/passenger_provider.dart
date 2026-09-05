import 'package:flutter/material.dart';
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

  Future<bool> checkAuth() async {
    final token = await api.getToken();
    if (token == null) return false;
    try {
      final profile = await api.getMe();
      user = profile;
      connectSocket(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String identifier, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.login(identifier, password);
      user = res['user'];
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
      user = res['user'];
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

  Future<void> logout() async {
    await api.clearAuth();
    socket.disconnect();
    user = null;
    resetTrip();
    notifyListeners();
  }
}
