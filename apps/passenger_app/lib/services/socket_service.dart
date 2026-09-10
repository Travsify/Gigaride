import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants.dart';

class SocketService {
  io.Socket? socket;
  bool isConnected = false;

  void connect(
    String token, {
    required Function(Map<String, dynamic> bid) onNewDriverBid,
    required Function(Map<String, dynamic> status) onRideStatusChanged,
    required Function(Map<String, dynamic> finished) onRideFinished,
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
      print('[Socket] Passenger connected to live gateway');
    });

    socket!.onDisconnect((_) {
      isConnected = false;
      print('[Socket] Passenger disconnected');
    });

    socket!.on('passenger:new_bid', (data) {
      if (data != null) {
        onNewDriverBid(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('ride:status_changed', (data) {
      if (data != null) {
        onRideStatusChanged(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('ride:finished', (data) {
      if (data != null) {
        onRideFinished(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('ride:completed', (data) {
      if (data != null) {
        onRideFinished(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('ride:trip_completed', (data) {
      if (data != null) {
        onRideFinished(Map<String, dynamic>.from(data));
      }
    });

    // 🚗 Live Driver GPS & Heading Stream
    socket!.on('ride:driver_location', (data) {
      if (data != null && onDriverLocationUpdate != null) {
        onDriverLocationUpdate!(Map<String, dynamic>.from(data));
      }
    });

    // ⚡ Driver Approaching Milestone (< 500m)
    socket!.on('ride:approaching', (data) {
      if (data != null && onDriverApproaching != null) {
        onDriverApproaching!(Map<String, dynamic>.from(data));
      }
    });

    // In-App Calling & Secure Signaling Listeners
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

    socket!.on('call:ended', (data) {
      if (data != null && onCallEnded != null) {
        onCallEnded!(Map<String, dynamic>.from(data));
      }
    });

    // In-App Chat Listeners
    socket!.on('ride:chat_message', (data) {
      if (data != null && onChatMessage != null) {
        onChatMessage!(Map<String, dynamic>.from(data));
      }
    });

    // 🚫 Ride Cancellation Listener
    socket!.on('ride:cancelled', (data) {
      if (data != null && onRideCancelled != null) {
        onRideCancelled!(Map<String, dynamic>.from(data));
      }
    });

    // ⚠️ Real-Time Issue Logged
    socket!.on('ride:issue_logged', (data) {
      if (data != null && onIssueLogged != null) {
        onIssueLogged!(Map<String, dynamic>.from(data));
      }
    });

    // 💵 Cash Change Credited to Wallet
    socket!.on('wallet:change_credited', (data) {
      if (data != null && onWalletChangeCredited != null) {
        onWalletChangeCredited!(Map<String, dynamic>.from(data));
      }
    });

    // ⏱️ Stopover Wait Time Listeners
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
  }

  // Telemetry, Call & Chat event callbacks
  Function(Map<String, dynamic>)? onDriverLocationUpdate;
  Function(Map<String, dynamic>)? onDriverApproaching;
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallConnected;
  Function(Map<String, dynamic>)? onCallEnded;
  Function(Map<String, dynamic>)? onChatMessage;
  Function(Map<String, dynamic>)? onRideCancelled;
  Function(Map<String, dynamic>)? onIssueLogged;
  Function(Map<String, dynamic>)? onWalletChangeCredited;
  Function(Map<String, dynamic>)? onWaitStarted;
  Function(Map<String, dynamic>)? onWaitEnded;

  Future<void> broadcastRide(String rideId) async {
    // Retry until socket is connected (handles race between ride creation and socket handshake)
    for (int attempt = 0; attempt < 8; attempt++) {
      if (socket != null && isConnected) {
        socket!.emit('ride:request', {'rideId': rideId});
        print('[Socket] Broadcasted ride:request for $rideId (attempt ${attempt + 1})');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
    // Last-ditch attempt regardless of isConnected flag
    socket?.emit('ride:request', {'rideId': rideId});
    print('[Socket] broadcastRide last-ditch emit for $rideId');
  }

  void acceptBid({required String rideId, required String driverId, required int agreedFareNgn}) {
    socket?.emit('passenger:accept_bid', {
      'rideId': rideId,
      'driverId': driverId,
      'agreedFareNgn': agreedFareNgn,
    });
  }

  // 🚫 Cancel Active Ride
  void cancelRide({required String rideId, String? reason}) {
    socket?.emit('ride:cancel', {
      'rideId': rideId,
      'reason': reason ?? 'Passenger cancelled',
    });
  }

  // ⚠️ Report In-Trip Safety / Quality Issue
  void reportRideIssue({
    required String rideId,
    required String issueType,
    required String description,
  }) {
    socket?.emit('ride:report_issue', {
      'rideId': rideId,
      'issueType': issueType,
      'description': description,
    });
  }

  // 💵 Settle Cash Change into Wallet
  void settleChangeToWallet({
    required String rideId,
    required int tenderedNgn,
    required int agreedFareNgn,
  }) {
    socket?.emit('ride:settle_change_to_wallet', {
      'rideId': rideId,
      'tenderedNgn': tenderedNgn,
      'agreedFareNgn': agreedFareNgn,
    });
  }

  // In-App VoIP Call Actions
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

  // In-App Chat Actions (with Hands-Free Voice Note / Audio Walkie-Talkie Support)
  void sendChatMessage({
    required String rideId,
    required String receiverId,
    required String text,
    bool isVoiceMemo = false,
    int? durationSecs,
  }) {
    socket?.emit('ride:chat_send', {
      'rideId': rideId,
      'receiverId': receiverId,
      'text': text,
      'isVoiceMemo': isVoiceMemo,
      'durationSecs': durationSecs,
    });
  }

  // Trigger Emergency SOS on Real-Time Gateway (alerts Admin console + LASEMA desk)
  void triggerSos({
    required String rideId,
    required double latitude,
    required double longitude,
    String? notes,
  }) {
    socket?.emit('ride:sos_trigger', {
      'rideId': rideId,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes ?? 'Passenger triggered in-transit SOS',
    });
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
  }
}
