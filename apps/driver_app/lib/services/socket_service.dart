import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants.dart';

class SocketService {
  io.Socket? socket;
  bool isConnected = false;

  void connect(
    String token, {
    required Function(Map<String, dynamic> request) onNewRideRequest,
    required Function(Map<String, dynamic> assignment) onRideAssigned,
    required Function(Map<String, dynamic> update) onSubscriptionUpdated,
    required Function(Map<String, dynamic> alert) onSubscriptionExhausted,
  }) {
    disconnect();

    socket = io.io(
      AppConstants.defaultSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket!.onConnect((_) {
      isConnected = true;
      print('[Socket] Driver connected to live dispatch gateway');
    });

    socket!.onDisconnect((_) {
      isConnected = false;
      print('[Socket] Driver disconnected');
    });

    socket!.on('ride:new_request', (data) {
      if (data != null) {
        onNewRideRequest(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('ride:assigned', (data) {
      if (data != null) {
        onRideAssigned(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('subscription:updated', (data) {
      if (data != null) {
        onSubscriptionUpdated(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('subscription:exhausted', (data) {
      if (data != null) {
        onSubscriptionExhausted(Map<String, dynamic>.from(data));
      }
    });

    // Ride Cancellation Listener
    socket!.on('ride:cancelled', (data) {
      if (data != null && onRideCancelled != null) {
        onRideCancelled!(Map<String, dynamic>.from(data));
      }
    });

    // In-App Chat Listeners
    socket!.on('ride:chat_message', (data) {
      if (data != null && onChatMessage != null) {
        onChatMessage!(Map<String, dynamic>.from(data));
      }
    });

    // In-App Secure Calling & Signaling Listeners
    socket!.on('call:incoming', (data) {
      if (data != null && onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('call:connected', (data) {
      if (data != null && onCallConnected != null) {
        onCallConnected!(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('call:token_ready', (data) {
      if (data != null && onCallTokenReady != null) {
        onCallTokenReady!(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('call:ended', (data) {
      if (data != null && onCallEnded != null) {
        onCallEnded!(Map<String, dynamic>.from(data));
      }
    });

    // Stopover & Round-Trip Wait Time Listeners
    socket!.on('ride:wait_started', (data) {
      if (data != null && onWaitStarted != null) {
        onWaitStarted!(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('ride:wait_ended', (data) {
      if (data != null && onWaitEnded != null) {
        onWaitEnded!(Map<String, dynamic>.from(data));
      }
    });

    // When a ride is taken by another driver or cancelled — remove from driver's list immediately
    socket!.on('ride:closed', (data) {
      if (data != null && onRideClosed != null) {
        onRideClosed!(Map<String, dynamic>.from(data));
      }
    });
  }

  Function(Map<String, dynamic>)? onWaitStarted;
  Function(Map<String, dynamic>)? onWaitEnded;
  Function(Map<String, dynamic>)? onRideClosed;
  Function(Map<String, dynamic>)? onRideCancelled;
  Function(Map<String, dynamic>)? onChatMessage;
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallConnected;
  Function(Map<String, dynamic>)? onCallTokenReady;
  Function(Map<String, dynamic>)? onCallEnded;

  // In-App Calling Actions
  void initiateCall({required String rideId, required String receiverId}) {
    socket?.emit('call:initiate', {
      'rideId': rideId,
      'receiverId': receiverId,
    });
  }

  void answerCall({required String rideId, required String callerId}) {
    socket?.emit('call:answer', {
      'rideId': rideId,
      'callerId': callerId,
    });
  }

  void endCall({required String rideId, required String targetId, String? reason}) {
    socket?.emit('call:end', {
      'rideId': rideId,
      'targetId': targetId,
      'reason': reason ?? 'Call ended',
    });
  }

  void updateLocation({
    required double latitude,
    required double longitude,
    bool isOnline = true,
    String? activeRideId,
    double? heading,
    double? speedKmh,
  }) {
    socket?.emit('driver:location', {
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'activeRideId': ?activeRideId,
      'heading': ?heading,
      'speedKmh': ?speedKmh,
    });
  }

  void submitBid({required String rideId, required int counterFareNgn, required int etaMinutes}) {
    socket?.emit('driver:submit_bid', {
      'rideId': rideId,
      'counterFareNgn': counterFareNgn,
      'etaMinutes': etaMinutes,
    });
  }

  void updateTripStatus({required String rideId, required String status}) {
    socket?.emit('driver:update_status', {
      'rideId': rideId,
      'status': status,
    });
  }

  void sendChatMessage({required String rideId, required String receiverId, required String text}) {
    socket?.emit('ride:chat_send', {
      'rideId': rideId,
      'receiverId': receiverId,
      'text': text,
    });
  }

  // ⏱️ Stopover & Round-Trip Wait Time Emitters
  void startWait({required String rideId, String? stopAddress}) {
    socket?.emit('ride:start_wait', {
      'rideId': rideId,
      'stopAddress': ?stopAddress,
    });
  }

  void resumeTrip({required String rideId}) {
    socket?.emit('ride:resume_trip', {
      'rideId': rideId,
    });
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
  }
}
