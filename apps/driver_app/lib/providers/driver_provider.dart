import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';

class DriverProvider with ChangeNotifier {
  final ApiService api = ApiService();
  final SocketService socket = SocketService();

  StreamSubscription<Position>? _gpsStreamSub;
  Timer? _gpsBroadcastTimer;

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

  // ⏱️ Stopover Wait Time State
  bool isWaitingAtStop = false;
  int waitElapsedSeconds = 0;
  int accruedDriverWaitEarnings = 0;
  int waitGraceMins = 5;
  int waitRatePerMin = 40;
  int waitCommissionPercent = 15;
  Timer? _waitTimer;

  // Daily Gross Earnings Summary
  double todayGrossEarningsNgn = 0;
  int todayCompletedTripsCount = 0;
  String? token;

  // 💬 In-memory persistent chat history per ride
  final Map<String, List<Map<String, dynamic>>> _rideChatHistory = {};

  List<Map<String, dynamic>> getChatMessages(String rideId) {
    return _rideChatHistory[rideId] ?? [];
  }

  void addChatMessage(String rideId, Map<String, dynamic> msg) {
    _rideChatHistory.putIfAbsent(rideId, () => []);
    final exists = _rideChatHistory[rideId]!.any((m) =>
        m['id'] != null && msg['id'] != null && m['id'] == msg['id']);
    if (!exists) {
      _rideChatHistory[rideId]!.add(msg);
      notifyListeners();
    }
  }

  void setChatMessages(String rideId, List<Map<String, dynamic>> messages) {
    _rideChatHistory[rideId] = List.from(messages);
    notifyListeners();
  }

  Future<bool> checkAuth() async {
    final t = await api.getToken();
    if (t == null) return false;
    token = t;
    try {
      final profile = await api.getMe();
      user = profile;
      driverProfile = profile['driverProfile'];
      connectSocket(t);
      // Secondary background refresh so splash screen never waits or times out
      unawaited(Future.wait([
        refreshSubscription(),
        loadVirtualAccount(),
        loadNotifications(),
      ]).catchError((e) {
        debugPrint('Background auth sync: $e');
        return <void>[];
      }));
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateProfileLocally({String? fullName, String? email}) {
    if (user != null) {
      if (fullName != null && fullName.trim().isNotEmpty) {
        user!['fullName'] = fullName.trim();
        user!['full_name'] = fullName.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        user!['email'] = email.trim();
      }
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
      driverProfile = res['driverProfile'];
      if (user != null && user!['id'] != null) {
        OneSignal.login(user!['id']);
      }
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
        token = res['token'];
        user = res['user'];
        driverProfile = res['driverProfile'];
        if (user != null && user!['id'] != null) {
          OneSignal.login(user!['id']);
        }
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
      return await api.verifyPhoneOtp(phoneNumber, otpCode);
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
      driverProfile = res['driverProfile'];
      if (user != null && user!['id'] != null) {
        OneSignal.login(user!['id']);
      }
      await refreshSubscription();
      await loadVirtualAccount();
      await loadNotifications();
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
      token = res['token'];
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
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        notifyListeners();
      },
      onRideAssigned: (assignment) {
        activeTrip = assignment;
        tripStep = 'ACCEPTED';
        incomingRequests.clear();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
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

    // Stopover & Round-Trip Wait Time Handlers
    socket.onWaitStarted = (data) {
      isWaitingAtStop = true;
      if (data['graceMinutes'] != null) {
        waitGraceMins = (data['graceMinutes'] as num).toInt();
      }
      if (data['ratePerMinute'] != null) {
        waitRatePerMin = (data['ratePerMinute'] as num).toInt();
      }
      _waitTimer?.cancel();
      _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        waitElapsedSeconds++;
        final totalWaitMins = (waitElapsedSeconds / 60).ceil();
        final billableMins = (totalWaitMins - waitGraceMins) > 0 ? (totalWaitMins - waitGraceMins) : 0;
        final totalWaitFare = billableMins * waitRatePerMin;
        final commission = (totalWaitFare * (waitCommissionPercent / 100)).round();
        accruedDriverWaitEarnings = totalWaitFare - commission;
        notifyListeners();
      });
      notifyListeners();
    };

    socket.onWaitEnded = (data) {
      isWaitingAtStop = false;
      _waitTimer?.cancel();
      notifyListeners();
    };

    // 💬 Persistent In-App Chat Listener
    socket.onChatMessage = (msgData) {
      final rId = (msgData['rideId'] ?? activeTrip?['rideId'] ?? activeTrip?['id'] ?? '').toString();
      if (rId.isNotEmpty) {
        addChatMessage(rId, msgData);
      }
    };

    // 🚗 Real-Time Ride Lifecycle & Status Listener
    socket.onRideStatusChanged = (statusData) {
      final changedRideId = (statusData['rideId'] ?? '').toString();
      final newStatus = (statusData['status'] ?? '').toString();
      final activeRideId = (activeTrip?['rideId'] ?? activeTrip?['id'] ?? '').toString();

      if (activeRideId.isNotEmpty && activeRideId == changedRideId) {
        if (newStatus == 'COMPLETED') {
          final fare = activeTrip != null
              ? (activeTrip!['agreedFareNgn'] ?? activeTrip!['counterFareNgn'] ?? activeTrip!['riderOfferNgn'] ?? 0)
              : 0;
          todayGrossEarningsNgn += (fare + accruedDriverWaitEarnings);
          todayCompletedTripsCount++;
          clearActiveTrip();
          refreshSubscription();
        } else if (newStatus.isNotEmpty) {
          tripStep = newStatus;
          notifyListeners();
        }
      }
    };

    socket.onRideCompleted = (completedData) {
      final changedRideId = (completedData['rideId'] ?? '').toString();
      final activeRideId = (activeTrip?['rideId'] ?? activeTrip?['id'] ?? '').toString();
      if (activeRideId.isNotEmpty && (changedRideId.isEmpty || activeRideId == changedRideId)) {
        final fare = activeTrip != null
            ? (activeTrip!['agreedFareNgn'] ?? activeTrip!['counterFareNgn'] ?? activeTrip!['riderOfferNgn'] ?? 0)
            : 0;
        todayGrossEarningsNgn += (fare + accruedDriverWaitEarnings);
        todayCompletedTripsCount++;
        clearActiveTrip();
        refreshSubscription();
      }
    };

    // When a ride is accepted by another driver or cancelled — remove it from this driver's radar list immediately
    socket.onRideClosed = (data) {
      final closedId = (data['rideId'] ?? '').toString();
      if (closedId.isNotEmpty) {
        incomingRequests.removeWhere((r) =>
          (r['rideId'] ?? r['id'] ?? r['ride_id'] ?? '').toString() == closedId);
        notifyListeners();
      }
    };

    socket.onRideCancelled = (data) {
      final cancelledId = (data['rideId'] ?? '').toString();
      if (cancelledId.isNotEmpty) {
        incomingRequests.removeWhere((r) =>
          (r['rideId'] ?? r['id'] ?? r['ride_id'] ?? '').toString() == cancelledId);
        if (activeTrip != null &&
            (activeTrip!['rideId'] ?? activeTrip!['id'] ?? '').toString() == cancelledId) {
          activeTrip = null;
          tripStep = null;
        }
        notifyListeners();
      }
    };

    // Broadcast initial live coordinates and start continuous GPS tracking
    LocationService.getLastKnownLocation().then((cachedPos) {
      final pos = cachedPos ?? LocationService.defaultLagosLocation;
      socket.updateLocation(latitude: pos.latitude, longitude: pos.longitude, isOnline: isOnline);
    }).catchError((_) {
      socket.updateLocation(latitude: 6.5244, longitude: 3.3792, isOnline: isOnline);
    });

    if (isOnline) {
      _startGpsStreaming();
    }
  }

  void _startGpsStreaming() {
    _stopGpsStreaming();
    // 1. High-precision movement stream (updates as vehicle moves)
    _gpsStreamSub = LocationService.getPositionStream().listen((Position pos) {
      if (isOnline) {
        socket.updateLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          isOnline: true,
          activeRideId: activeTrip?['rideId'] ?? activeTrip?['id'],
          heading: pos.heading,
          speedKmh: pos.speed * 3.6,
        );
      }
    });

    // 2. Periodic heartbeat every 12 seconds to maintain radar freshness
    // Uses cached coordinates to avoid blocking the main UI thread with GPS locks (prevents ANR)
    _gpsBroadcastTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (isOnline) {
        final pos = LocationService.lastKnownUserLocation ?? LocationService.defaultLagosLocation;
        socket.updateLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          isOnline: true,
          activeRideId: activeTrip?['rideId'] ?? activeTrip?['id'],
        );
      }
    });
  }

  void _stopGpsStreaming() {
    _gpsStreamSub?.cancel();
    _gpsStreamSub = null;
    _gpsBroadcastTimer?.cancel();
    _gpsBroadcastTimer = null;
  }

  void updateLocation(double latitude, double longitude) {
    if (isOnline) {
      socket.updateLocation(
        latitude: latitude,
        longitude: longitude,
        isOnline: true,
        activeRideId: activeTrip?['rideId'] ?? activeTrip?['id'],
      );
    }
  }

  bool toggleOnline() {
    final kyc = driverProfile?['kyc_status'];
    if (kyc != 'APPROVED') {
      isOnline = false;
      _stopGpsStreaming();
      notifyListeners();
      return false;
    }
    isOnline = !isOnline;
    if (isOnline) {
      LocationService.getCurrentLocation().then((pos) {
        socket.updateLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          isOnline: true,
        );
      }).catchError((_) {
        socket.updateLocation(latitude: 6.5244, longitude: 3.3792, isOnline: true);
      });
      _startGpsStreaming();
      fetchBroadcastedFares();
    } else {
      _stopGpsStreaming();
      LocationService.getCurrentLocation().then((pos) {
        socket.updateLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          isOnline: false,
        );
      }).catchError((_) {});
      incomingRequests.clear();
    }
    notifyListeners();
    return true;
  }

  Future<void> fetchBroadcastedFares() async {
    try {
      final fares = await api.fetchAvailableBroadcastedRides();
      final Set<String> serverRideIds = fares
          .map((f) => (f['rideId'] ?? f['id'] ?? f['ride_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      // Remove stale/expired/accepted rides no longer returned by the server
      final int initialCount = incomingRequests.length;
      incomingRequests.removeWhere((r) {
        final id = (r['rideId'] ?? r['id'] ?? r['ride_id'] ?? '').toString();
        return id.isNotEmpty && !serverRideIds.contains(id);
      });
      bool stateChanged = incomingRequests.length != initialCount;

      for (final fare in fares) {
        final rId = (fare['rideId'] ?? fare['id'] ?? fare['ride_id'] ?? '').toString();
        if (rId.isNotEmpty && !incomingRequests.any((r) => (r['rideId'] ?? r['id'] ?? r['ride_id']).toString() == rId)) {
          incomingRequests.add(Map<String, dynamic>.from(fare));
          stateChanged = true;
        }
      }
      if (stateChanged) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchBroadcastedFares error: $e');
    }
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

  void startWaitTime(String rideId, {String? stopAddress}) {
    socket.startWait(rideId: rideId, stopAddress: stopAddress);
    isWaitingAtStop = true;
    waitElapsedSeconds = 0;
    accruedDriverWaitEarnings = 0;
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      waitElapsedSeconds++;
      final totalWaitMins = (waitElapsedSeconds / 60).ceil();
      final billableMins = (totalWaitMins - waitGraceMins) > 0 ? (totalWaitMins - waitGraceMins) : 0;
      final totalWaitFare = billableMins * waitRatePerMin;
      final commission = (totalWaitFare * (waitCommissionPercent / 100)).round();
      accruedDriverWaitEarnings = totalWaitFare - commission;
      notifyListeners();
    });
    notifyListeners();
  }

  void resumeTripFromWait(String rideId) {
    socket.resumeTrip(rideId: rideId);
    isWaitingAtStop = false;
    _waitTimer?.cancel();
    notifyListeners();
  }

  void updateTripStatus(String status, {String? overrideRideId}) {
    final rId = (overrideRideId != null && overrideRideId.isNotEmpty)
        ? overrideRideId
        : (activeTrip != null ? (activeTrip!['rideId'] ?? activeTrip!['id'] ?? activeTrip!['ride_id'] ?? '').toString() : '');
    
    if (rId.isNotEmpty) {
      socket.updateTripStatus(
        rideId: rId,
        status: status,
      );
      // Resilient HTTP PATCH fallback in case socket dropped
      api.updateRideStatus(rId, status).catchError((e) {
        debugPrint('HTTP status update error: $e');
        return <String, dynamic>{};
      });
    }

    tripStep = status;
    if (status == 'COMPLETED') {
      if (rId.isNotEmpty) {
        socket.socket?.emit('ride:completed', {'rideId': rId});
        socket.socket?.emit('ride:finish', {'rideId': rId});
      }
      final fare = activeTrip != null
          ? (activeTrip!['agreedFareNgn'] ?? activeTrip!['counterFareNgn'] ?? activeTrip!['riderOfferNgn'] ?? 0)
          : 0;
      todayGrossEarningsNgn += (fare + accruedDriverWaitEarnings);
      todayCompletedTripsCount++;
      activeTrip = null;
      tripStep = null;
      isWaitingAtStop = false;
      _waitTimer?.cancel();
      waitElapsedSeconds = 0;
      accruedDriverWaitEarnings = 0;
      refreshSubscription();
    }
    notifyListeners();
  }

  void clearActiveTrip() {
    activeTrip = null;
    tripStep = null;
    isWaitingAtStop = false;
    _waitTimer?.cancel();
    waitElapsedSeconds = 0;
    accruedDriverWaitEarnings = 0;
    notifyListeners();
  }

  Future<void> logout() async {
    _stopGpsStreaming();
    OneSignal.logout();
    await api.clearAuth();
    socket.disconnect();
    _waitTimer?.cancel();
    isWaitingAtStop = false;
    waitElapsedSeconds = 0;
    accruedDriverWaitEarnings = 0;
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
