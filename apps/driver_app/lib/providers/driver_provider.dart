import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class DriverProvider with ChangeNotifier {
  final ApiService api = ApiService();
  final SocketService socket = SocketService();

  bool isLoading = false;
  Map<String, dynamic>? user;
  Map<String, dynamic>? driverProfile;
  
  // Subscription state
  bool hasActiveSubscription = false;
  int remainingRides = 0;
  String? planName;
  bool isGracePeriod = false;

  // Radar / Trip state
  bool isOnline = true;
  List<Map<String, dynamic>> incomingRequests = [];
  Map<String, dynamic>? activeTrip;
  String? tripStep; // 'ARRIVED', 'IN_TRANSIT', 'COMPLETED'

  Future<bool> checkAuth() async {
    final token = await api.getToken();
    if (token == null) return false;
    try {
      final profile = await api.getMe();
      user = profile;
      driverProfile = profile['driverProfile'];
      await refreshSubscription();
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
      driverProfile = res['driverProfile'];
      await refreshSubscription();
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(Map<String, dynamic> data) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.registerDriver(
        fullName: data['fullName'],
        phoneNumber: data['phoneNumber'],
        email: data['email'],
        password: data['password'],
        vehicleMake: data['vehicleMake'],
        vehicleModel: data['vehicleModel'],
        vehicleYear: data['vehicleYear'],
        licensePlate: data['licensePlate'],
        vehicleColor: data['vehicleColor'],
        nin: data['nin'],
      );
      user = res['user'];
      driverProfile = res['driverProfile'];
      await refreshSubscription();
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSubscription() async {
    try {
      final sub = await api.getSubscriptionStatus();
      hasActiveSubscription = sub['hasActiveSubscription'] ?? false;
      remainingRides = sub['remainingRides'] ?? 0;
      planName = sub['planName'];
      isGracePeriod = sub['isGracePeriod'] ?? false;
      notifyListeners();
    } catch (e) {
      print('Failed to refresh subscription: $e');
    }
  }

  Future<void> purchasePlan(String planId) async {
    isLoading = true;
    notifyListeners();
    try {
      await api.purchaseSubscription(planId);
      await refreshSubscription();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void connectSocket(String token) {
    socket.connect(
      token,
      onNewRideRequest: (req) {
        // Prevent duplicate requests
        incomingRequests.removeWhere((r) => r['rideId'] == req['rideId']);
        incomingRequests.insert(0, req);
        notifyListeners();
      },
      onRideAssigned: (assignment) {
        activeTrip = assignment;
        tripStep = 'ACCEPTED';
        incomingRequests.clear();
        notifyListeners();
      },
      onSubscriptionUpdated: (update) {
        remainingRides = update['remainingRides'] ?? remainingRides;
        isGracePeriod = update['graceUsed'] ?? false;
        if (update['isExhausted'] == true) {
          hasActiveSubscription = false;
        }
        notifyListeners();
      },
      onSubscriptionExhausted: (alert) {
        hasActiveSubscription = false;
        notifyListeners();
      },
    );

    // Broadcast default coordinates (Lagos Yaba area)
    socket.updateLocation(latitude: 6.518, longitude: 3.379, isOnline: true);
  }

  void toggleOnline() {
    isOnline = !isOnline;
    socket.updateLocation(
      latitude: 6.518,
      longitude: 3.379,
      isOnline: isOnline,
    );
    if (!isOnline) {
      incomingRequests.clear();
    }
    notifyListeners();
  }

  void submitCounterOffer(String rideId, int counterFareNgn, int etaMinutes) {
    socket.submitBid(
      rideId: rideId,
      counterFareNgn: counterFareNgn,
      etaMinutes: etaMinutes,
    );
    // Remove from radar once bid is sent
    incomingRequests.removeWhere((r) => r['rideId'] == rideId);
    notifyListeners();
  }

  void updateTripStatus(String status) {
    if (activeTrip == null) return;
    socket.updateTripStatus(
      rideId: activeTrip!['rideId'],
      status: status,
    );
    tripStep = status;
    if (status == 'COMPLETED') {
      activeTrip = null;
      tripStep = null;
      refreshSubscription();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await api.clearAuth();
    socket.disconnect();
    user = null;
    driverProfile = null;
    activeTrip = null;
    incomingRequests.clear();
    notifyListeners();
  }
}
