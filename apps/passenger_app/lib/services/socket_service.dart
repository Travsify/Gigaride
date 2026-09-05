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
  }

  // Call & Chat event callbacks
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallConnected;
  Function(Map<String, dynamic>)? onCallEnded;
  Function(Map<String, dynamic>)? onChatMessage;

  void broadcastRide(String rideId) {
    socket?.emit('ride:request', {'rideId': rideId});
  }

  void acceptBid({required String rideId, required String driverId, required int agreedFareNgn}) {
    socket?.emit('passenger:accept_bid', {
      'rideId': rideId,
      'driverId': driverId,
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

  // In-App Chat Actions
  void sendChatMessage({required String rideId, required String receiverId, required String text}) {
    socket?.emit('ride:chat_send', {
      'rideId': rideId,
      'receiverId': receiverId,
      'text': text,
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
