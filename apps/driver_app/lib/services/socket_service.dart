import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants.dart';

class SocketService {
  IO.Socket? socket;
  bool isConnected = false;

  void connect(
    String token, {
    required Function(Map<String, dynamic> request) onNewRideRequest,
    required Function(Map<String, dynamic> assignment) onRideAssigned,
    required Function(Map<String, dynamic> update) onSubscriptionUpdated,
    required Function(Map<String, dynamic> alert) onSubscriptionExhausted,
  }) {
    disconnect();

    socket = IO.io(
      AppConstants.defaultSocketUrl,
      IO.OptionBuilder()
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
  }

  void updateLocation({required double latitude, required double longitude, bool isOnline = true}) {
    socket?.emit('driver:location', {
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
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

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
  }
}
