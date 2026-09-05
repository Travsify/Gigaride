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
  }

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

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
  }
}
