import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class DriverProvider with ChangeNotifier {
  final ApiService api = ApiService();
  final SocketService socket = SocketService();

  bool isLoading = false;
  Map<String, dynamic>? user;
  Map<String, dynamic>? driverProfile;
  Map<String, dynamic>? virtualAccount;
  
  // Subscription state
  bool hasActiveSubscription = false;
  int remainingRides = 0;
  String? planName;
  bool isGracePeriod = false;
  List<dynamic> subscriptionPlans = [];

  // Notifications
  List<dynamic> notifications = [];
  int unreadNotificationsCount = 0;

  // Radar / Trip state
  bool isOnline = true;
  List<Map<String, dynamic>> incomingRequests = [];
  Map<String, dynamic>? activeTrip;
  String? tripStep; // 'ARRIVED', 'IN_TRANSIT', 'COMPLETED'

  // Daily Gross Earnings Summary
  double todayGrossEarningsNgn = 0;
  int todayCompletedTripsCount = 0;

  Future<bool> checkAuth() async {
    final token = await api.getToken();
    if (token == null) return false;
    try {
      final profile = await api.getMe();
      user = profile;
      driverProfile = profile['driverProfile'];
      await refreshSubscription();
      await loadVirtualAccount();
      await loadNotifications();
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
      await loadVirtualAccount();
      await loadNotifications();
      connectSocket(res['token']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithPhoneOtp(String phoneNumber, String otpCode) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await api.verifyPhoneOtp(phoneNumber, otpCode);
      if (res['token'] != null) {
        user = res['user'];
        driverProfile = res['driverProfile'];
        await refreshSubscription();
        await loadVirtualAccount();
        await loadNotifications();
        connectSocket(res['token']);
      }
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
      await loadVirtualAccount();
      await loadNotifications();
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

      // Also load available plans
      subscriptionPlans = await api.getSubscriptionPlans();
      notifyListeners();
    } catch (e) {
      print('Failed to refresh subscription: $e');
    }
  }

  Future<void> loadVirtualAccount() async {
    try {
      virtualAccount = await api.getDedicatedVirtualAccount();
      notifyListeners();
    } catch (e) {
      print('Failed to load virtual account: $e');
    }
  }

  Future<void> loadNotifications() async {
    try {
      final data = await api.getNotifications();
      notifications = data['notifications'] ?? [];
      unreadNotificationsCount = data['unreadCount'] ?? 0;
      notifyListeners();
    } catch (e) {
      print('Failed to load notifications: $e');
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await api.markNotificationRead(id);
      final idx = notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) {
        notifications[idx]['is_read'] = true;
        if (unreadNotificationsCount > 0) unreadNotificationsCount--;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await api.markAllNotificationsRead();
      for (var n in notifications) {
        n['is_read'] = true;
      }
      unreadNotificationsCount = 0;
      notifyListeners();
    } catch (_) {}
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

  Future<Map<String, dynamic>> initializeCardPayment(String planId) async {
    return await api.initializeCardPayment(planId);
  }

  Future<void> verifyNIN(String nin, String firstName, String lastName, {String? dob}) async {
    isLoading = true;
    notifyListeners();
    try {
      await api.verifyNIN(nin, firstName, lastName, dob: dob);
      if (driverProfile != null) {
        driverProfile!['kyc_status'] = 'APPROVED';
      }
      await loadVirtualAccount();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyLicense(String licenseNumber, String firstName, String lastName, {String? dob}) async {
    isLoading = true;
    notifyListeners();
    try {
      await api.verifyDriversLicense(licenseNumber, firstName, lastName, dob: dob);
      if (driverProfile != null) {
        driverProfile!['kyc_status'] = 'APPROVED';
      }
      await loadVirtualAccount();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void connectSocket(String token) {
    socket.connect(
      token,
      onNewRideRequest: (req) {
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

  bool toggleOnline() {
    final kyc = driverProfile?['kyc_status'];
    if (kyc != 'APPROVED') {
      isOnline = false;
      notifyListeners();
      return false;
    }
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
    return true;
  }

  void submitCounterOffer(String rideId, int counterFareNgn, int etaMinutes) {
    socket.submitBid(
      rideId: rideId,
      counterFareNgn: counterFareNgn,
      etaMinutes: etaMinutes,
    );
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
      final fare = activeTrip!['agreedFareNgn'] ?? activeTrip!['counterFareNgn'] ?? 0;
      todayGrossEarningsNgn += fare;
      todayCompletedTripsCount++;
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
    virtualAccount = null;
    activeTrip = null;
    incomingRequests.clear();
    notifications.clear();
    unreadNotificationsCount = 0;
    notifyListeners();
  }
}
