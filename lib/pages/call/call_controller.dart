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
import '../../services/signaling_channel.dart';

/// Viewer côté appel : une session (`sid`) avec une caméra, protocole v1.
class CallController extends GetxController {
  final SignalingService _signalingService = Get.find();

  Rx<Device> target = Rx<Device>(Device('--'));
  RxBool enableVideo = true.obs;
  RxBool enableAudio = true.obs;
  RxBool connected = false.obs;

  /// Message d'erreur affiché dans la vue ; non vide = session terminée en erreur.
  RxString error = ''.obs;

  /// Barre de contrôle masquée automatiquement après 4 s.
  final RxBool controlsVisible = true.obs;

  /// Durée d'appel (`03:12`) et lien (`Direct · 2.4 Mb/s`), pour l'affichage.
  final RxString elapsed = '00:00'.obs;
  final RxString linkLabel = ''.obs;
  final RxBool relayed = false.obs;

  final GlobalKey videoRenderKey = GlobalKey();

  /// Zoom / déplacement de la vidéo (pincer ; double tap pour revenir à 1×).
  final TransformationController zoom = TransformationController();

  void resetZoom() => zoom.value = Matrix4.identity();

  webrtc.MediaStream? _remoteStream;
  webrtc.RTCPeerConnection? _rtcPeerConnection;
  final webrtc.RTCVideoRenderer remoteRTCVideoRenderer =
      webrtc.RTCVideoRenderer();

  final String _sid = _randomSid();

  bool _offerSent = false;
  bool _remoteDescSet = false;
  bool _gatheringDone = false;
  bool _byeSent = false;
  bool _remoteEnded = false; // bye / error reçu : on ne renvoie pas de bye
  bool _closed = false;
  bool _left = false;

  final List<webrtc.RTCIceCandidate> _pendingRemoteCandidates = [];
  final List<Map<String, dynamic>> _outCandidates = [];
  Timer? _outTimer;
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

  /// Boutons selon les capacités annoncées par la caméra.
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

  Future<void> _initializeAudio() async {
    await webrtc.Helper.setAndroidAudioConfiguration(
      webrtc.AndroidAudioConfiguration(
        androidAudioMode: webrtc.AndroidAudioMode.normal,
        androidAudioStreamType: webrtc.AndroidAudioStreamType.music,
        androidAudioAttributesUsageType:
            webrtc.AndroidAudioAttributesUsageType.media,
      ),
    );
    webrtc.Helper.selectAudioOutput('speaker');
    webrtc.Helper.setSpeakerphoneOnButPreferBluetooth();
  }

  Future<void> _startCall() async {
    final args = Get.arguments;
    if (args is! List || args.isEmpty || args[0] is! Device) {
      _leave();
      return;
    }
    target.value = args[0] as Device;

    final pc = await webrtc.createPeerConnection({
      'iceServers':
          _signalingService.iceConfig?.servers ?? IceConfig.defaultServers,
    });
    _rtcPeerConnection = pc;

    pc.onIceCandidate = _queueLocalCandidate;
    pc.onIceGatheringState = (state) {
      if (state == webrtc.RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _gatheringDone = true;
        _flushLocalCandidates(end: true);
      }
    };
    pc.onConnectionState = _onConnectionState;
    // Unified Plan : les médias arrivent par `onTrack` (onAddStream n'est
    // plus déclenché de façon fiable).
    pc.onTrack = (event) async {
      debugPrint('[RTC] track ${event.track.kind}, streams=${event.streams.length}');
      // L'audio est lu par la PeerConnection elle-même ; le renderer ne sert
      // qu'à la vidéo. Brancher le flux deux fois (audio puis vidéo)
      // réinitialisait le rendu natif et pouvait laisser un écran noir.
      if (event.track.kind != 'video' || _remoteStream != null) return;
      var stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) {
        // la caméra n'a pas annoncé de flux (msid) : on en fabrique un
        stream = await webrtc.createLocalMediaStream('remote');
        await stream.addTrack(event.track);
      }
      _remoteStream = stream;
      remoteRTCVideoRenderer.srcObject = stream;
    };
    pc.onIceConnectionState =
        (state) => debugPrint('[RTC] ice connection: $state');

    await _createOffer(pc);
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
        // la connexion peut se rétablir seule : on laisse 10 s
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

  Future<void> _createOffer(webrtc.RTCPeerConnection pc) async {
    final offer = await pc.createOffer({
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true}
    });
    await pc.setLocalDescription(offer);
    if (_closed) return;

    _signalingService.sendTo(
      target.value.id,
      Envelope('offer', {
        'sdp': offer.sdp,
        'want': {'audio': true},
      }, sid: _sid),
    );
    _offerSent = true;
    _answerTimer = Timer(
        _answerTimeout, () => _fail('No answer from the camera', 'timeout'));
    _flushLocalCandidates(end: _gatheringDone);
  }

  // ---- messages entrants -------------------------------------------------

  void _onInbox(String fromId, Envelope env) {
    if (_closed || fromId != target.value.id) return;

    if (env.type == 'res') {
      _onCommandResult(env.data);
      return;
    }
    // tout autre message doit appartenir à l'appel en cours
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
    final pc = _rtcPeerConnection;
    final sdp = data['sdp'];
    if (pc == null || _remoteDescSet || sdp is! String) return;
    _answerTimer?.cancel();
    try {
      await pc
          .setRemoteDescription(webrtc.RTCSessionDescription(sdp, 'answer'));
    } catch (e) {
      _fail('Invalid answer from the camera', 'user');
      return;
    }
    _remoteDescSet = true;
    // candidats arrivés avant la réponse (trickle)
    for (final c in _pendingRemoteCandidates) {
      await _addCandidate(c);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> _onIce(Map<String, dynamic> data) async {
    final list = data['candidates'];
    if (list is! List) return;
    for (final item in list) {
      if (item is! Map || item['candidate'] is! String) continue;
      final cand = webrtc.RTCIceCandidate(
        item['candidate'] as String,
        item['sdpMid'] as String?,
        item['sdpMLineIndex'] as int?,
      );
      if (_remoteDescSet) {
        await _addCandidate(cand);
      } else {
        _pendingRemoteCandidates.add(cand);
      }
    }
  }

  Future<void> _addCandidate(webrtc.RTCIceCandidate cand) async {
    final pc = _rtcPeerConnection;
    if (pc == null) return;
    try {
      await pc.addCandidate(cand);
    } catch (e) {
      debugPrint('addCandidate failed: $e');
    }
  }

  void _onError(Map<String, dynamic> data) {
    // une `error` termine la session : jamais suivie d'un `bye`
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

  // ---- fin de session ----------------------------------------------------

  /// Termine l'appel côté viewer (bouton, `bye` reçu, perte de connexion).
  Future<void> hangup([String reason = 'user']) async {
    if (_left) return;
    _sendBye(reason);
    await _teardown();
    _leave();
  }

  /// Échec local : on prévient la caméra, puis on affiche l'erreur avant de quitter.
  Future<void> _fail(String message, String reason) async {
    _sendBye(reason);
    await _showError(message);
  }

  /// Libère l'appel mais reste sur l'écran pour afficher [message].
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
    _outTimer?.cancel();
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
      // l'aperçu doit être pris avant de détacher le flux
      await captureSnapshot();
      remoteRTCVideoRenderer.srcObject = null;
      for (final track in remote.getTracks()) {
        await track.stop();
      }
      await remote.dispose();
    }

    final pc = _rtcPeerConnection;
    _rtcPeerConnection = null;
    if (pc != null) {
      await pc.close();
      debugPrint('RTCPeerConnection closed');
    }
    connected.value = false;
  }

  // ---- ICE sortant -------------------------------------------------------

  void _queueLocalCandidate(webrtc.RTCIceCandidate c) {
    final text = c.candidate;
    if (text == null || text.isEmpty) return;
    _outCandidates.add({
      'candidate': text,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    });
    // regroupés par fenêtres de ~100 ms
    _outTimer ??=
        Timer(const Duration(milliseconds: 100), _flushLocalCandidates);
  }

  void _flushLocalCandidates({bool end = false}) {
    _outTimer?.cancel();
    _outTimer = null;
    if (!_offerSent || _closed) return; // renvoyé après l'offre
    if (_outCandidates.isEmpty && !end) return;
    _signalingService.sendTo(
      target.value.id,
      Envelope('ice', {
        'candidates': List.of(_outCandidates),
        'end': end,
      }, sid: _sid),
    );
    _outCandidates.clear();
  }

  // ---- affichage ---------------------------------------------------------

  void showControls() {
    controlsVisible.value = true;
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (connected.value && error.value.isEmpty) controlsVisible.value = false;
    });
  }

  void toggleControls() =>
      controlsVisible.value ? controlsVisible.value = false : showControls();

  static num? _num(dynamic v) => v is num ? v : num.tryParse('$v');

  /// Type de lien (direct / relayé) et débit vidéo, depuis `getStats()`.
  Future<void> _pollStats() async {
    final pc = _rtcPeerConnection;
    if (pc == null) return;
    try {
      final start = _connectedAt;
      if (start != null) {
        final d = DateTime.now().difference(start);
        String two(int n) => n.toString().padLeft(2, '0');
        elapsed.value = '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
      }

      final reports = await pc.getStats();
      final byId = {for (final r in reports) r.id: r};
      num bytes = 0;
      bool? isRelay;
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
        }
      }

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
        linkLabel.value = '${isRelay ? 'Relayed' : 'Direct'}$rate';
      }
    } catch (e) {
      debugPrint('getStats failed: $e');
    }
  }

  // ---- commandes ---------------------------------------------------------

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

  void remoteSwitchCamera() => _sendCommand('flip');

  // ---- médias ------------------------------------------------------------

  void toggleVideo() {
    enableVideo.value = !enableVideo.value;
    for (final track in _remoteStream?.getVideoTracks() ?? []) {
      track.enabled = enableVideo.value;
    }
  }

  void toggleAudio() {
    enableAudio.value = !enableAudio.value;
    for (final track in _remoteStream?.getAudioTracks() ?? []) {
      track.enabled = enableAudio.value;
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
