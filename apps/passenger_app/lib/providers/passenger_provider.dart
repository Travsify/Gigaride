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

  Future<void> logout() async {
    await api.clearAuth();
    socket.disconnect();
    user = null;
    resetTrip();
    notifyListeners();
  }
}
