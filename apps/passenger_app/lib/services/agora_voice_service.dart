import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraVoiceService {
  static final AgoraVoiceService instance = AgoraVoiceService._internal();
  AgoraVoiceService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isJoined = false;

  final String defaultAppId = '57d797d4eb6143769bd02999aed126ad';

  Function(int uid)? onUserJoined;
  Function(int uid, UserOfflineReasonType reason)? onUserOffline;
  Function(ConnectionStateType state, ConnectionChangedReasonType reason)? onConnectionStateChanged;
  Function(ErrorCodeType err, String msg)? onError;

  bool get isJoined => _isJoined;

  Future<bool> initialize({String? appId}) async {
    if (_isInitialized && _engine != null) return true;

    final targetAppId = (appId != null && appId.isNotEmpty) ? appId : defaultAppId;

    try {
      // 1. Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('[AgoraVoice] Microphone permission denied');
        return false;
      }

      // 2. Create RTC Engine instance
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: targetAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        audioScenario: AudioScenarioType.audioScenarioDefault,
      ));

      // 3. Register Event Handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[AgoraVoice] Joined channel: ${connection.channelId} with uid: ${connection.localUid}');
            _isJoined = true;
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AgoraVoice] Remote user $remoteUid joined');
            if (onUserJoined != null) onUserJoined!(remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[AgoraVoice] Remote user $remoteUid left: $reason');
            if (onUserOffline != null) onUserOffline!(remoteUid, reason);
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('[AgoraVoice] Connection state: $state, reason: $reason');
            if (onConnectionStateChanged != null) onConnectionStateChanged!(state, reason);
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AgoraVoice] Error: $err - $msg');
            if (onError != null) onError!(err, msg);
          },
        ),
      );

      // 4. Configure Audio Pipeline: Enable voice, disable video, set earpiece/speakerphone
      await _engine!.enableAudio();
      await _engine!.enableLocalAudio(true); // Explicitly enable mic hardware capture
      await _engine!.adjustRecordingSignalVolume(100); // Max mic volume
      await _engine!.adjustPlaybackSignalVolume(100); // Max incoming volume
      await _engine!.disableVideo();
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
      // Default to earpiece for passenger privacy
      await _engine!.setEnableSpeakerphone(false);

      _isInitialized = true;
      debugPrint('[AgoraVoice] Initialized successfully with App ID: $targetAppId');
      return true;
    } catch (e) {
      debugPrint('[AgoraVoice] Failed to initialize Agora Engine: $e');
      return false;
    }
  }

  Future<void> joinChannel({
    required String channelId,
    String? token,
    int uid = 0,
    String? appId,
  }) async {
    // Prevent double-joining the same channel (drops the local audio track)
    if (_isJoined) {
      debugPrint('[AgoraVoice] Already joined channel, ignoring duplicate join request');
      return;
    }

    final ready = await initialize(appId: appId);
    if (!ready || _engine == null) {
      debugPrint('[AgoraVoice] Engine not ready, cannot join channel');
      return;
    }

    try {
      final effectiveToken = (token != null && token.isNotEmpty) ? token : '';
      await _engine!.joinChannel(
        token: effectiveToken,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
      _isJoined = true;
      debugPrint('[AgoraVoice] Requested to join channel $channelId');
    } catch (e) {
      debugPrint('[AgoraVoice] Error joining channel $channelId: $e');
    }
  }

  Future<void> mute(bool muted) async {
    if (_engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(muted);
      debugPrint('[AgoraVoice] Local audio muted: $muted');
    } catch (e) {
      debugPrint('[AgoraVoice] Error muting: $e');
    }
  }

  Future<void> toggleSpeaker(bool speakerOn) async {
    if (_engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(speakerOn);
      debugPrint('[AgoraVoice] Speakerphone set to: $speakerOn');
    } catch (e) {
      debugPrint('[AgoraVoice] Error toggling speaker: $e');
    }
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;
    try {
      await _engine!.leaveChannel();
      _isJoined = false;
      debugPrint('[AgoraVoice] Left channel successfully');
    } catch (e) {
      debugPrint('[AgoraVoice] Error leaving channel: $e');
    }
  }

  Future<void> dispose() async {
    await leaveChannel();
    if (_engine != null) {
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
      _isInitialized = false;
    }
  }
}
