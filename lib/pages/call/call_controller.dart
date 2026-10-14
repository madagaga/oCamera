import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:get/get.dart';
import '../../models/devices.dart';
import '../../models/envelope.dart';
import '../../models/ice_config.dart';
import '../../routes/app_pages.dart';
import '../../services/peer_session.dart';
import '../../services/signaling_channel.dart';

/// Call-side viewer: one session (`sid`) with a camera, protocol v1.
enum AudioOutput { earpiece, speaker, off }

class CallController extends GetxController {
  final SignalingService _signalingService = Get.find();

  Rx<Device> target = Rx<Device>(Device('--'));
  RxBool enableVideo = true.obs;
  /// Where the camera audio goes: earpiece, loudspeaker or nowhere.
  final Rx<AudioOutput> audioOutput = AudioOutput.earpiece.obs;
  RxBool connected = false.obs;

  /// Error message shown in the view; non-empty = session ended with an error.
  RxString error = ''.obs;

  /// Control bar hidden automatically after 4 s.
  final RxBool controlsVisible = true.obs;

  /// Call duration (`03:12`) and link (`Direct · 2.4 Mb/s`), for display.
  final RxString elapsed = '00:00'.obs;
  final RxString linkLabel = ''.obs;
  final RxBool relayed = false.obs;

  final GlobalKey videoRenderKey = GlobalKey();

  /// Video zoom / pan (pinch; double tap to return to 1×).
  final TransformationController zoom = TransformationController();

  void resetZoom() => zoom.value = Matrix4.identity();

  webrtc.MediaStream? _remoteStream;
  PeerSession? _peer;
  final webrtc.RTCVideoRenderer remoteRTCVideoRenderer =
      webrtc.RTCVideoRenderer();

  final String _sid = _randomSid();

  bool _offerSent = false;
  bool _byeSent = false;
  bool _remoteEnded = false; // bye / error received: do not send a bye back
  bool _closed = false;
  bool _left = false;

  Timer? _answerTimer;
  Timer? _disconnectTimer;
  Timer? _hideControlsTimer;
  Timer? _statsTimer;
  DateTime? _connectedAt;
  num _lastBytes = 0;
  DateTime? _lastStatsAt;
  final Map<String, Timer> _pendingCmds = {};
  int _cmdCounter = 0;

  static const _answerTimeout = Duration(seconds: 15);
  static const _disconnectGrace = Duration(seconds: 10);
  static const _cmdTimeout = Duration(seconds: 10);

  CallController();

  static String _randomSid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Buttons according to the capabilities announced by the camera.
  bool get canFlip => target.value.caps.cmds.contains('flip');
  bool get canToggleVideo => target.value.isPhone;

  @override
  Future<void> onInit() async {
    super.onInit();
    _signalingService.onInbox = _onInbox;
    await remoteRTCVideoRenderer.initialize();
    remoteRTCVideoRenderer.addListener(() {
      final v = remoteRTCVideoRenderer.value;
      debugPrint('[RTC] renderer: ${v.width}x${v.height} renderVideo=${v.renderVideo}');
    });
    remoteRTCVideoRenderer.onFirstFrameRendered =
        () => debugPrint('[RTC] first frame rendered');
    await _initializeAudio();
    await _startCall();
  }

  @override
  Future<void> onClose() async {
    if (_signalingService.onInbox == _onInbox) {
      _signalingService.onInbox = null;
    }
    _sendBye('user');
    await _teardown();
    await remoteRTCVideoRenderer.dispose();
    zoom.dispose();
    super.onClose();
  }

  /// Call-style audio routing: the earpiece by default, the loudspeaker on
  /// request ([AudioOutput.speaker]). Routing is driven by setSpeakerphoneOn, which
  /// needs the communication audio mode.
  Future<void> _initializeAudio() async {
    await webrtc.Helper.setAndroidAudioConfiguration(
      webrtc.AndroidAudioConfiguration(
        androidAudioMode: webrtc.AndroidAudioMode.inCommunication,
        androidAudioStreamType: webrtc.AndroidAudioStreamType.voiceCall,
        androidAudioAttributesUsageType:
            webrtc.AndroidAudioAttributesUsageType.voiceCommunication,
      ),
    );
    await webrtc.Helper.setSpeakerphoneOn(audioOutput.value == AudioOutput.speaker);
  }

  /// Selects the audio output; [AudioOutput.off] mutes the camera audio.
  Future<void> setAudioOutput(AudioOutput output) async {
    audioOutput.value = output;
    for (final track in _remoteStream?.getAudioTracks() ?? []) {
      track.enabled = output != AudioOutput.off;
    }
    if (output != AudioOutput.off) {
      await webrtc.Helper.setSpeakerphoneOn(output == AudioOutput.speaker);
    }
  }

  Future<void> _startCall() async {
    final args = Get.arguments;
    if (args is! List || args.isEmpty || args[0] is! Device) {
      _leave();
      return;
    }
    target.value = args[0] as Device;

    final peer = PeerSession(
      iceServers:
          _signalingService.iceConfig?.servers ?? IceConfig.defaultServers,
      sendIce: (cands, end) => _signalingService.sendTo(
        target.value.id,
        Envelope('ice', {'candidates': cands, 'end': end}, sid: _sid),
      ),
      onConnectionState: _onConnectionState,
      onRemoteVideo: (stream) {
        _remoteStream = stream;
        remoteRTCVideoRenderer.srcObject = stream;
        // re-apply the selected output (e.g. "No sound" chosen before the stream arrived)
        setAudioOutput(audioOutput.value);
      },
    );
    _peer = peer;
    await peer.init();

    await _createOffer(peer);
  }

  void _onConnectionState(webrtc.RTCPeerConnectionState state) {
    debugPrint(' ********** $state');
    switch (state) {
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        if (!connected.value) {
          connected.value = true;
          _connectedAt = DateTime.now();
          _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStats());
          showControls();
        }
        break;
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        // the connection may recover on its own: allow 10 s
        _disconnectTimer ??=
            Timer(_disconnectGrace, () => hangup('ice_failed'));
        break;
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        hangup('ice_failed');
        break;
      default:
        break;
    }
  }

  Future<void> _createOffer(PeerSession peer) async {
    final sdp = await peer.createOffer();
    if (_closed) return;

    _signalingService.sendTo(
      target.value.id,
      Envelope('offer', {
        'sdp': sdp,
        'want': {
          'audio': true,
          // only when the user chose one; otherwise the camera picks its default
          if (target.value.stream != null) 'stream': target.value.stream,
        },
      }, sid: _sid),
    );
    _offerSent = true;
    _answerTimer = Timer(
        _answerTimeout, () => _fail('No answer from the camera', 'timeout'));
    peer.markSignalingReady();
  }

  // ---- incoming messages -------------------------------------------------

  void _onInbox(String fromId, Envelope env) {
    if (_closed || fromId != target.value.id) return;

    if (env.type == 'res') {
      _onCommandResult(env.data);
      return;
    }
    // any other message must belong to the current call
    if (env.sid != _sid) return;

    switch (env.type) {
      case 'answer':
        _onAnswer(env.data);
        break;
      case 'ice':
        _onIce(env.data);
        break;
      case 'bye':
        _remoteEnded = true;
        hangup();
        break;
      case 'error':
        _onError(env.data);
        break;
    }
  }

  Future<void> _onAnswer(Map<String, dynamic> data) async {
    final peer = _peer;
    final sdp = data['sdp'];
    if (peer == null || sdp is! String) return;
    _answerTimer?.cancel();
    try {
      await peer.setRemoteAnswer(sdp);
    } catch (e) {
      _fail('Invalid answer from the camera', 'user');
    }
  }

  Future<void> _onIce(Map<String, dynamic> data) async {
    final list = data['candidates'];
    if (list is List) await _peer?.addRemoteCandidates(list);
  }

  void _onError(Map<String, dynamic> data) {
    // an `error` ends the session: never followed by a `bye`
    _remoteEnded = true;
    final code = data['code']?.toString() ?? '';
    final message = switch (code) {
      'busy' => 'The camera is already in use',
      'bad_request' => 'The camera rejected the request',
      'unsupported_codec' => 'No video codec in common with the camera',
      'source_unavailable' => 'The camera video source is unreachable',
      'stale' => 'Clock mismatch between this device and the camera',
      _ => data['message']?.toString() ?? 'Unknown error',
    };
    _showError(message);
  }

  // ---- session end -------------------------------------------------------

  /// Ends the call on the viewer side (button, `bye` received, connection lost).
  Future<void> hangup([String reason = 'user']) async {
    if (_left) return;
    _sendBye(reason);
    await _teardown();
    _leave();
  }

  /// Local failure: notify the camera, then show the error before leaving.
  Future<void> _fail(String message, String reason) async {
    _sendBye(reason);
    await _showError(message);
  }

  /// Releases the call but stays on screen to display [message].
  Future<void> _showError(String message) async {
    error.value = message;
    await _teardown();
  }

  void _sendBye(String reason) {
    if (_byeSent || _remoteEnded || !_offerSent) return;
    _byeSent = true;
    _signalingService.sendTo(
        target.value.id, Envelope('bye', {'reason': reason}, sid: _sid));
  }

  void _leave() {
    if (_left) return;
    _left = true;
    Get.back();
  }

  Future<void> _teardown() async {
    if (_closed) return;
    _closed = true;
    _answerTimer?.cancel();
    _disconnectTimer?.cancel();
    _hideControlsTimer?.cancel();
    _statsTimer?.cancel();
    for (final t in _pendingCmds.values) {
      t.cancel();
    }
    _pendingCmds.clear();

    debugPrint('Hanging up call with ${target.value.name}');

    final remote = _remoteStream;
    _remoteStream = null;
    if (remote != null) {
      // the preview must be captured before detaching the stream
      await captureSnapshot();
      remoteRTCVideoRenderer.srcObject = null;
      for (final track in remote.getTracks()) {
        await track.stop();
      }
      await remote.dispose();
    }

    final peer = _peer;
    _peer = null;
    await peer?.close();
    connected.value = false;
  }

  // ---- display -----------------------------------------------------------

  void showControls() {
    controlsVisible.value = true;
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (connected.value && error.value.isEmpty) controlsVisible.value = false;
    });
  }

  void toggleControls() =>
      controlsVisible.value ? controlsVisible.value = false : showControls();

  static String _codecName(String mime) {
    final name = mime.split('/').last.toUpperCase();
    return name == 'H264' ? 'H.264' : name == 'H265' ? 'H.265' : name;
  }

  static num? _num(dynamic v) => v is num ? v : num.tryParse('$v');

  /// Link type (direct / relayed) and video bitrate, from `getStats()`.
  Future<void> _pollStats() async {
    final peer = _peer;
    if (peer == null) return;
    try {
      final start = _connectedAt;
      if (start != null) {
        final d = DateTime.now().difference(start);
        String two(int n) => n.toString().padLeft(2, '0');
        elapsed.value = '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
      }

      final reports = await peer.getStats();
      final byId = {for (final r in reports) r.id: r};
      num bytes = 0;
      bool? isRelay;
      String? codecId;
      for (final r in reports) {
        final v = r.values;
        if (r.type == 'candidate-pair' &&
            '${v['nominated']}' == 'true' &&
            '${v['state']}' == 'succeeded') {
          final local = byId[v['localCandidateId']]?.values['candidateType'];
          final remote = byId[v['remoteCandidateId']]?.values['candidateType'];
          isRelay = local == 'relay' || remote == 'relay';
        } else if (r.type == 'inbound-rtp' &&
            ('${v['kind']}' == 'video' || '${v['mediaType']}' == 'video')) {
          bytes = _num(v['bytesReceived']) ?? bytes;
          codecId = v['codecId']?.toString();
        }
      }

      // negotiated video codec, e.g. "video/H264" -> "H.264"
      final mime = byId[codecId]?.values['mimeType']?.toString();
      final codec = mime == null ? '' : ' · ${_codecName(mime)}';

      final now = DateTime.now();
      var rate = '';
      final last = _lastStatsAt;
      if (last != null) {
        final secs = now.difference(last).inMilliseconds / 1000;
        if (secs > 0 && bytes >= _lastBytes) {
          final mbps = (bytes - _lastBytes) * 8 / secs / 1e6;
          rate = mbps >= 1
              ? ' · ${mbps.toStringAsFixed(1)} Mb/s'
              : ' · ${(mbps * 1000).round()} kb/s';
        }
      }
      _lastBytes = bytes;
      _lastStatsAt = now;
      if (isRelay != null) {
        relayed.value = isRelay;
        linkLabel.value = '${isRelay ? 'Relayed' : 'Direct'}$codec$rate';
      }
    } catch (e) {
      debugPrint('getStats failed: $e');
    }
  }

  // ---- commands ----------------------------------------------------------

  void _sendCommand(String name, [Map<String, dynamic>? args]) {
    final id = 'c-${++_cmdCounter}';
    _pendingCmds[id] = Timer(_cmdTimeout, () {
      _pendingCmds.remove(id);
      Get.snackbar('Command', 'No answer from the camera');
    });
    _signalingService.sendTo(
      target.value.id,
      Envelope('cmd', {'id': id, 'name': name, if (args != null) 'args': args}),
    );
  }

  void _onCommandResult(Map<String, dynamic> data) {
    _pendingCmds.remove(data['id'])?.cancel();
    if (data['ok'] == true) return;
    final err = data['error'];
    final msg = err is Map ? err['message']?.toString() : null;
    Get.snackbar('Command failed', msg ?? 'The camera refused the command');
  }

  /// Restarts the call with another stream (SD / HD). The camera allows one
  /// session at a time, so the current one is closed first.
  Future<void> changeStream(String name) async {
    final device = target.value;
    if (_left || name == device.activeStream) return;
    device.stream = name;
    _sendBye('user');
    await _teardown();
    _left = true;
    Get.back();
    // let the old route and its controller go before building the new one
    await Future.delayed(const Duration(milliseconds: 350));
    Get.toNamed(Routes.CALL, arguments: [device]);
  }

  void remoteSwitchCamera() => _sendCommand('flip');

  // ---- media -------------------------------------------------------------

  void toggleVideo() {
    enableVideo.value = !enableVideo.value;
    for (final track in _remoteStream?.getVideoTracks() ?? []) {
      track.enabled = enableVideo.value;
    }
  }

  Future<void> captureSnapshot() async {
    try {
      final context = videoRenderKey.currentContext;
      if (context == null) return;
      final boundary = context.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        target.value.snapshot = byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error capturing snapshot: $e');
    }
  }
}
