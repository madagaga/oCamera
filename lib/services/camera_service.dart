import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:get/get.dart';

import '../models/camera_profile.dart';
import '../models/devices.dart';
import '../models/envelope.dart';
import '../models/ice_config.dart';
import '../models/user.dart';
import 'hardware_codecs.dart';
import 'peer_session.dart';
import 'signaling_channel.dart';

/// Capture and bitrate settings of one quality. Tune them with the bitrate
/// badge of the live view: a phone encoder needs more bits than an IP camera
/// sub-stream for the same quality, so SD relies on a small picture and a low
/// frame rate rather than on the cap alone.
class StreamProfile {
  final int width;
  final int height;
  final int fps;
  final int maxBitrate; // bits per second
  const StreamProfile(this.width, this.height, this.fps, this.maxBitrate);
}

/// Same names as the IP camera agent: `sub` = SD, `main` = HD.
/// The first entry is the default when the viewer does not choose.
const Map<String, StreamProfile> kStreamProfiles = {
  'sub': StreamProfile(480, 270, 10, 180000),
  'main': StreamProfile(1280, 720, 15, 1000000),
};

/// This phone in camera mode: publishes its `state`, answers viewers'
/// offers and applies the session rules of MQTT_PROTOCOL.md § 7
/// (a single session, `busy` for the others, session endings, log).
///
/// No GetX or screen: the state is exposed as `Rx` for the UI.
class CameraService {
  CameraService(this._signaling);

  final SignalingService _signaling;

  late CameraProfile _profile;

  /// Video codecs with a hardware encoder on this phone; only these are offered.
  List<String> _hwCodecs = const [];

  /// MQTT connection established, current session and its viewer.
  final RxBool mqttConnected = false.obs;
  final RxBool busy = false.obs;
  final Rxn<String> viewer = Rxn<String>();
  final RxBool running = false.obs;

  String? _sid;
  String? _viewer;
  PeerSession? _peer;
  webrtc.MediaStream? _local;
  Envelope? _lastAnswer;
  DateTime? _startedAt;
  Timer? _connectTimer;
  Timer? _disconnectTimer;

  static const _connectTimeout = Duration(seconds: 30);
  static const _disconnectGrace = Duration(seconds: 10);

  /// Returns `true` if the connection to the broker is established.
  Future<bool> start(User user) async {
    if (running.value) return true;
    running.value = true;
    _hwCodecs = await HardwareCodecs.videoEncoders();
    _profile = CameraProfile(
      name: user.deviceName.isEmpty ? user.name : user.deviceName,
      caps: DeviceCaps(
        video: _hwCodecs,
        audio: const ['opus'],
        streams: const ['sub', 'main'],
        cmds: const ['flip', 'torch'],
      ),
    );
    _signaling.cameraProfile = _profile;
    _signaling.onInbox = _onInbox;
    _signaling.onStale = _onStale;
    _signaling.onConnected = (ok) {
      mqttConnected.value = ok;
      if (ok) _publishState(); // reconnection: republish the exact state
    };
    await _signaling.connect(user);
    if (!_signaling.connected.value) {
      running.value = false;
      return false;
    }
    return true;
  }

  /// Stop requested: closes the session, announces `online:false`, then disconnects.
  Future<void> stop() async {
    if (!running.value) return;
    await _end('shutdown', sendBye: true);
    _signaling.publishState(_profile.state(online: false, busy: false));
    _signaling.onInbox = null;
    _signaling.onStale = null;
    _signaling.onConnected = null;
    _signaling.disconnect();
    _signaling.cameraProfile = null;
    mqttConnected.value = false;
    running.value = false;
  }

  void _publishState() {
    _signaling.publishState(
        _profile.state(online: true, busy: _sid != null, viewer: _viewer));
  }

  // ---- incoming messages -------------------------------------------------

  void _onStale(String from, Envelope env) {
    // only a stale offer gets a reply (§ 4)
    if (env.type == 'offer') {
      _sendError(from, env.sid, 'stale', 'Check the clock', retryable: true);
    }
  }

  void _onInbox(String from, Envelope env) {
    switch (env.type) {
      case 'offer':
        _onOffer(from, env);
        break;
      case 'ice':
        if (_matches(from, env)) {
          final list = env.data['candidates'];
          if (list is List) _peer?.addRemoteCandidates(list);
        }
        break;
      case 'bye':
        if (_matches(from, env)) _end('user', sendBye: false);
        break;
      case 'cmd':
        _onCommand(from, env);
        break;
      default:
        debugPrint('[Camera] ignoring ${env.type}');
    }
  }

  bool _matches(String from, Envelope env) =>
      _sid != null && env.sid == _sid && from == _viewer;

  Future<void> _onOffer(String from, Envelope env) async {
    final sid = env.sid;
    final sdp = env.data['sdp'];

    if (_sid != null) {
      if (sid == _sid && from == _viewer) {
        // duplicate: resend the same answer
        final answer = _lastAnswer;
        if (answer != null) _signaling.sendToViewer(from, answer);
      } else {
        _sendError(from, sid, 'busy', 'Session already active', retryable: true);
      }
      return;
    }
    if (sid == null || sdp is! String) {
      _sendError(from, sid, 'bad_request', 'Invalid offer');
      return;
    }

    // the camera is reserved before any `await`: a second offer gets `busy`
    _sid = sid;
    _viewer = from;
    _startedAt = DateTime.now();
    busy.value = true;
    viewer.value = from;
    _publishState();
    debugPrint('[Camera] session start sid=$sid viewer=$from');

    try {
      final want = env.data['want'];
      final wantAudio = want is Map ? want['audio'] != false : true;
      final streamName =
          want is Map && want['stream'] is String ? want['stream'] as String : kStreamProfiles.keys.first;
      final profile = kStreamProfiles[streamName];
      if (profile == null) {
        // unknown stream: the session ends with an error, never with a bye
        await _end('error', sendBye: false);
        _sendError(from, sid, 'bad_request', 'Unknown stream $streamName');
        return;
      }

      final local = await webrtc.navigator.mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'environment',
          // Plain numbers: flutter_webrtc ignores the `{ideal: n}` form on
          // Android and falls back to 1280x720 at 30 fps.
          'width': profile.width,
          'height': profile.height,
          'frameRate': profile.fps,
        },
        'audio': wantAudio,
      });
      if (_sid != sid) {
        // session closed while the camera was opening
        await _stopStream(local);
        return;
      }
      _local = local;

      final peer = PeerSession(
        iceServers: IceConfig.defaultServers,
        sendIce: (cands, end) => _signaling.sendToViewer(
          from,
          Envelope('ice', {'candidates': cands, 'end': end}, sid: sid),
        ),
        onConnectionState: _onConnectionState,
      );
      _peer = peer;
      await peer.init();
      await peer.addLocalStream(local);
      final answerSdp =
          await peer.createAnswer(sdp, allowedVideoCodecs: _hwCodecs);
      await peer.limitVideoSender(
          maxBitrate: profile.maxBitrate, maxFramerate: profile.fps);
      if (_sid != sid) return;

      final answer = Envelope('answer', {'sdp': answerSdp}, sid: sid);
      _lastAnswer = answer;
      _signaling.sendToViewer(from, answer);
      peer.markSignalingReady();
      _connectTimer = Timer(_connectTimeout, () => _end('timeout', sendBye: true));
    } catch (e) {
      debugPrint('[Camera] offer failed: $e');
      final code = e is UnsupportedCodecError
          ? 'unsupported_codec'
          : '$e'.contains('NotAllowed') || '$e'.contains('Permission')
              ? 'source_unavailable'
              : 'internal';
      // an `error` ends the session: never followed by a `bye`
      await _end('error', sendBye: false);
      _sendError(from, sid, code,
          code == 'unsupported_codec' ? 'No hardware-encoded codec in common' : 'Camera unavailable');
    }
  }

  void _onConnectionState(webrtc.RTCPeerConnectionState state) {
    switch (state) {
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _connectTimer?.cancel();
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        break;
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _disconnectTimer ??=
            Timer(_disconnectGrace, () => _end('ice_failed', sendBye: true));
        break;
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _end('ice_failed', sendBye: true);
        break;
      default:
        break;
    }
  }

  // ---- commands ----------------------------------------------------------

  Future<void> _onCommand(String from, Envelope env) async {
    final id = env.data['id']?.toString() ?? '';
    final name = env.data['name']?.toString() ?? '';
    final args = env.data['args'];

    void reply(bool ok, [String? code, String? message]) {
      _signaling.sendToViewer(
        from,
        Envelope('res', {
          'id': id,
          'ok': ok,
          if (!ok) 'error': {'code': code, 'message': message},
        }),
      );
    }

    final tracks = _local?.getVideoTracks() ?? const [];
    try {
      switch (name) {
        case 'flip':
          if (tracks.isEmpty) return reply(false, 'unavailable', 'No active camera');
          await webrtc.Helper.switchCamera(tracks.first);
          return reply(true);
        case 'torch':
          if (tracks.isEmpty) return reply(false, 'unavailable', 'No active camera');
          final on = args is Map && args['on'] == true;
          await tracks.first.setTorch(on);
          return reply(true);
        default:
          return reply(false, 'unsupported', 'Unknown command');
      }
    } catch (e) {
      reply(false, 'failed', '$e');
    }
  }

  // ---- session end -------------------------------------------------------

  Future<void> _end(String reason, {required bool sendBye}) async {
    final sid = _sid;
    if (sid == null) return;
    final viewerId = _viewer;
    final secs = DateTime.now().difference(_startedAt ?? DateTime.now()).inSeconds;
    debugPrint('[Camera] session end sid=$sid reason=$reason duration=${secs}s');

    _connectTimer?.cancel();
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    if (sendBye && viewerId != null) {
      _signaling.sendToViewer(
          viewerId, Envelope('bye', {'reason': reason}, sid: sid));
    }

    final peer = _peer;
    final local = _local;
    _sid = null;
    _viewer = null;
    _peer = null;
    _local = null;
    _lastAnswer = null;
    busy.value = false;
    viewer.value = null;

    await peer?.close();
    await _stopStream(local);
    _publishState();
  }

  Future<void> _stopStream(webrtc.MediaStream? stream) async {
    if (stream == null) return;
    for (final t in stream.getTracks()) {
      await t.stop();
    }
    await stream.dispose();
  }

  void _sendError(String to, String? sid, String code, String message,
      {bool retryable = false}) {
    _signaling.sendToViewer(
      to,
      Envelope('error', {
        'code': code,
        'message': message,
        'retryable': retryable,
      }, sid: sid),
    );
  }
}
