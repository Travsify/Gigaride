import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'socket_service.dart';

class CustomAudioCallService {
  static final CustomAudioCallService instance = CustomAudioCallService._internal();
  CustomAudioCallService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  String? _currentRideId;
  String? _remoteUserId;
  SocketService? _socketService;

  Function(bool connected)? onConnectionStateChanged;
  Function(String error)? onError;

  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  final Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _audioConstraints = {
    'audio': {
      'mandatory': {
        'googEchoCancellation': true,
        'googEchoCancellation2': true,
        'googDAEchoCancellation': true,
        'googAutoGainControl': true,
        'googHighpassFilter': true,
        'googNoiseSuppression': true,
        'googTypingNoiseDetection': true,
        'googAudioMirroring': false,
      },
      'optional': <Map<String, dynamic>>[],
    },
    'video': false,
  };

  String _optimizeSdpForVoice(String sdp) {
    // Force Opus to use mono (stereo=0), voice coding, and enable in-band FEC
    return sdp.replaceAll(
      'useinbandfec=1',
      'useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1;maxaveragebitrate=24000',
    );
  }

  Future<bool> initialize({
    required String rideId,
    required String remoteUserId,
    required SocketService socketService,
  }) async {
    _currentRideId = rideId;
    _remoteUserId = remoteUserId;
    _socketService = socketService;

    try {
      // 1. Request microphone hardware permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('[WebRTC Audio] Microphone permission denied');
        onError?.call('Microphone permission denied');
        return false;
      }

      // 2. Create WebRTC RTCPeerConnection
      _peerConnection = await createPeerConnection(_rtcConfiguration);

      // 3. Acquire local audio stream with Acoustic Echo Cancellation & Noise Suppression
      _localStream = await navigator.mediaDevices.getUserMedia(_audioConstraints);
      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // 4. Register WebRTC Peer Connection Listeners
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && _currentRideId != null && _remoteUserId != null) {
          _socketService?.sendCallIceCandidate(
            rideId: _currentRideId!,
            targetId: _remoteUserId!,
            candidate: candidate.toMap(),
          );
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC Audio] Peer connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _isConnected = true;
          onConnectionStateChanged?.call(true);
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                   state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                   state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _isConnected = false;
          onConnectionStateChanged?.call(false);
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[WebRTC Audio] Remote track received: ${event.track.kind}');
        if (event.track.kind == 'audio') {
          _remoteStream = event.streams.isNotEmpty ? event.streams.first : null;
          _isConnected = true;
          onConnectionStateChanged?.call(true);
        }
      };

      // 5. Initialize speakerphone mode
      await toggleSpeaker(_isSpeakerOn);

      _isInitialized = true;
      debugPrint('[WebRTC Audio] Audio call service initialized successfully for ride $rideId');
      return true;
    } catch (e) {
      debugPrint('[WebRTC Audio] Failed to initialize WebRTC engine: $e');
      onError?.call('Failed to initialize audio: $e');
      return false;
    }
  }

  /// Caller side: Initiates SDP Offer with mono & AEC optimization
  Future<void> sendOffer() async {
    if (_peerConnection == null || _currentRideId == null || _remoteUserId == null) {
      debugPrint('[WebRTC Audio] Cannot send offer: not initialized');
      return;
    }

    try {
      final RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });

      final optimizedSdp = _optimizeSdpForVoice(offer.sdp ?? '');
      final optimizedOffer = RTCSessionDescription(optimizedSdp, offer.type);
      await _peerConnection!.setLocalDescription(optimizedOffer);

      _socketService?.sendCallSignalOffer(
        rideId: _currentRideId!,
        targetId: _remoteUserId!,
        sdp: optimizedOffer.toMap(),
      );
      debugPrint('[WebRTC Audio] Sent optimized SDP offer to $_remoteUserId');
    } catch (e) {
      debugPrint('[WebRTC Audio] Error creating offer: $e');
      onError?.call('Error starting call: $e');
    }
  }

  /// Callee side: Handles remote SDP Offer and responds with optimized SDP Answer
  Future<void> handleRemoteOffer(Map<String, dynamic> sdp) async {
    if (_peerConnection == null) {
      debugPrint('[WebRTC Audio] PeerConnection null on handleRemoteOffer');
      return;
    }

    try {
      final rawSdp = sdp['sdp']?.toString() ?? '';
      final description = RTCSessionDescription(_optimizeSdpForVoice(rawSdp), sdp['type'] ?? 'offer');
      await _peerConnection!.setRemoteDescription(description);

      final RTCSessionDescription answer = await _peerConnection!.createAnswer();
      final optimizedAnswerSdp = _optimizeSdpForVoice(answer.sdp ?? '');
      final optimizedAnswer = RTCSessionDescription(optimizedAnswerSdp, answer.type);
      await _peerConnection!.setLocalDescription(optimizedAnswer);

      if (_currentRideId != null && _remoteUserId != null) {
        _socketService?.sendCallSignalAnswer(
          rideId: _currentRideId!,
          targetId: _remoteUserId!,
          sdp: optimizedAnswer.toMap(),
        );
        debugPrint('[WebRTC Audio] Sent optimized SDP answer to $_remoteUserId');
      }
    } catch (e) {
      debugPrint('[WebRTC Audio] Error handling offer: $e');
    }
  }

  /// Caller side: Handles remote SDP Answer
  Future<void> handleRemoteAnswer(Map<String, dynamic> sdp) async {
    if (_peerConnection == null) return;
    try {
      final description = RTCSessionDescription(sdp['sdp'], sdp['type'] ?? 'answer');
      await _peerConnection!.setRemoteDescription(description);
      debugPrint('[WebRTC Audio] Set remote description from answer');
    } catch (e) {
      debugPrint('[WebRTC Audio] Error handling answer: $e');
    }
  }

  /// Both sides: Adds received ICE Candidate
  Future<void> handleRemoteCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null) return;
    try {
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      debugPrint('[WebRTC Audio] Added remote ICE candidate');
    } catch (e) {
      debugPrint('[WebRTC Audio] Error adding candidate: $e');
    }
  }

  /// Mute or unmute local microphone hardware
  void mute(bool muted) {
    _isMuted = muted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
      debugPrint('[WebRTC Audio] Microphone mute set to: $muted');
    }
  }

  /// Toggle speakerphone vs earpiece output
  Future<void> toggleSpeaker(bool speakerOn) async {
    _isSpeakerOn = speakerOn;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
      debugPrint('[WebRTC Audio] Speakerphone set to: $speakerOn');
    } catch (e) {
      debugPrint('[WebRTC Audio] Error setting speakerphone: $e');
    }
  }

  /// Clean teardown of media streams and peer connection
  Future<void> endCall() async {
    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          track.stop();
        }
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      if (_peerConnection != null) {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
        _peerConnection = null;
      }
    } catch (e) {
      debugPrint('[WebRTC Audio] Error during call teardown: $e');
    } finally {
      _isInitialized = false;
      _isConnected = false;
      _isMuted = false;
      _currentRideId = null;
      _remoteUserId = null;
      _socketService = null;
      debugPrint('[WebRTC Audio] Call ended and resources released');
    }
  }
}
