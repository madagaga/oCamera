import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

/// A WebRTC connection, without GetX or UI: used by the viewer (offer) as well
/// as by the phone camera (answer). The caller handles signaling:
/// [sendIce] hands it the local candidates, already batched.
class PeerSession {
  PeerSession({
    required this.iceServers,
    required this.sendIce,
    this.onConnectionState,
    this.onRemoteVideo,
  });

  final List<Map<String, dynamic>> iceServers;

  /// Local candidates batched (~100 ms window); `end` when gathering finishes.
  final void Function(List<Map<String, dynamic>> candidates, bool end) sendIce;
  final void Function(webrtc.RTCPeerConnectionState state)? onConnectionState;
  final void Function(webrtc.MediaStream stream)? onRemoteVideo;

  webrtc.RTCPeerConnection? _pc;
  webrtc.MediaStream? _remoteStream;
  bool _remoteDescSet = false;
  bool _signalingReady = false;
  bool _gatheringDone = false;
  bool _closed = false;

  final List<webrtc.RTCIceCandidate> _pendingRemote = [];
  final List<Map<String, dynamic>> _outCandidates = [];
  Timer? _outTimer;

  bool get isClosed => _closed;
  webrtc.MediaStream? get remoteStream => _remoteStream;

  Future<void> init() async {
    final pc = await webrtc.createPeerConnection({'iceServers': iceServers});
    _pc = pc;
    pc.onIceCandidate = _queueLocalCandidate;
    pc.onIceGatheringState = (state) {
      if (state == webrtc.RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _gatheringDone = true;
        _flushLocal(end: true);
      }
    };
    pc.onConnectionState = (s) {
      debugPrint('[RTC] connection: $s');
      onConnectionState?.call(s);
    };
    pc.onIceConnectionState = (s) => debugPrint('[RTC] ice connection: $s');
    // Unified Plan: media arrives via onTrack. Only the video is used for
    // display (audio is played by the PeerConnection); attaching the stream
    // twice would reset the native rendering.
    pc.onTrack = (event) async {
      debugPrint('[RTC] track ${event.track.kind}, streams=${event.streams.length}');
      if (event.track.kind != 'video' || _remoteStream != null) return;
      var stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) {
        stream = await webrtc.createLocalMediaStream('remote');
        await stream.addTrack(event.track);
      }
      _remoteStream = stream;
      onRemoteVideo?.call(stream);
    };
  }

  /// Adds the tracks of a local stream (camera side).
  Future<void> addLocalStream(webrtc.MediaStream stream) async {
    final pc = _pc;
    if (pc == null) return;
    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }
  }

  /// Viewer side: creates the offer (recvonly video + audio) and sets it locally.
  Future<String> createOffer({bool audio = true}) async {
    final pc = _pc!;
    final offer = await pc.createOffer({
      'mandatory': {'OfferToReceiveAudio': audio, 'OfferToReceiveVideo': true}
    });
    await pc.setLocalDescription(offer);
    return offer.sdp!;
  }

  /// Camera side: applies the received offer and returns the answer (already
  /// set locally). With [allowedVideoCodecs] (lower-case names such as `h264`)
  /// only those video codecs can be negotiated; if the offer has none of them
  /// an [UnsupportedCodecError] is thrown.
  Future<String> createAnswer(String offerSdp,
      {List<String>? allowedVideoCodecs}) async {
    final pc = _pc!;
    await pc.setRemoteDescription(webrtc.RTCSessionDescription(offerSdp, 'offer'));
    await _remoteDescApplied();
    if (allowedVideoCodecs != null) {
      if (allowedVideoCodecs.isEmpty) throw UnsupportedCodecError();
      await _restrictVideoCodecs(pc, allowedVideoCodecs);
    }
    final answer = await pc.createAnswer();
    final sdp = answer.sdp!;
    // a rejected video m-line (port 0) means no codec in common
    if (allowedVideoCodecs != null && RegExp(r'^m=video 0 ', multiLine: true).hasMatch(sdp)) {
      throw UnsupportedCodecError();
    }
    await pc.setLocalDescription(answer);
    return sdp;
  }

  Future<void> _restrictVideoCodecs(
      webrtc.RTCPeerConnection pc, List<String> allowed) async {
    const auxiliary = {'rtx', 'red', 'ulpfec', 'flexfec-03'};
    final names = allowed.map((n) => n.toLowerCase()).toSet();
    final caps = await webrtc.getRtpSenderCapabilities('video');
    final filtered = (caps.codecs ?? []).where((c) {
      final name = c.mimeType.split('/').last.toLowerCase();
      return names.contains(name) || auxiliary.contains(name);
    }).toList();
    for (final t in await pc.getTransceivers()) {
      if (t.sender.track?.kind == 'video') {
        await t.setCodecPreferences(filtered);
      }
    }
  }

  /// Viewer side: applies the camera's answer.
  Future<void> setRemoteAnswer(String sdp) async {
    final pc = _pc;
    if (pc == null || _remoteDescSet) return;
    await pc.setRemoteDescription(webrtc.RTCSessionDescription(sdp, 'answer'));
    await _remoteDescApplied();
  }

  Future<void> _remoteDescApplied() async {
    _remoteDescSet = true;
    for (final c in _pendingRemote) {
      await _addCandidate(c);
    }
    _pendingRemote.clear();
  }

  /// Remote candidates; queued until the remote description is set
  /// (trickle). `sdpMid` / `sdpMLineIndex` may be null.
  Future<void> addRemoteCandidates(List<dynamic> list) async {
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
        _pendingRemote.add(cand);
      }
    }
  }

  Future<void> _addCandidate(webrtc.RTCIceCandidate cand) async {
    try {
      await _pc?.addCandidate(cand);
    } catch (e) {
      debugPrint('addCandidate failed: $e');
    }
  }

  /// Call once the offer / answer is published: local candidates can
  /// be sent (they must never precede the description).
  void markSignalingReady() {
    _signalingReady = true;
    _flushLocal(end: _gatheringDone);
  }

  void _queueLocalCandidate(webrtc.RTCIceCandidate c) {
    final text = c.candidate;
    if (text == null || text.isEmpty) return;
    _outCandidates.add({
      'candidate': text,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    });
    _outTimer ??= Timer(const Duration(milliseconds: 100), _flushLocal);
  }

  void _flushLocal({bool end = false}) {
    _outTimer?.cancel();
    _outTimer = null;
    if (!_signalingReady || _closed) return;
    if (_outCandidates.isEmpty && !end) return;
    sendIce(List.of(_outCandidates), end);
    _outCandidates.clear();
  }

  /// Caps the outgoing video (camera side). Without a cap WebRTC ramps the
  /// bitrate up as far as the network allows.
  Future<void> limitVideoSender({int? maxBitrate, int? maxFramerate}) async {
    final pc = _pc;
    if (pc == null) return;
    for (final sender in await pc.getSenders()) {
      if (sender.track?.kind != 'video') continue;
      final params = sender.parameters;
      final encodings = params.encodings ?? [];
      if (encodings.isEmpty) encodings.add(webrtc.RTCRtpEncoding());
      for (final e in encodings) {
        if (maxBitrate != null) e.maxBitrate = maxBitrate;
        if (maxFramerate != null) e.maxFramerate = maxFramerate;
      }
      params.encodings = encodings;
      final ok = await sender.setParameters(params);
      debugPrint('[RTC] video cap maxBitrate=$maxBitrate fps=$maxFramerate ok=$ok');
    }
  }

  Future<List<webrtc.StatsReport>> getStats() async =>
      await _pc?.getStats() ?? [];

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _outTimer?.cancel();
    _remoteStream = null;
    final pc = _pc;
    _pc = null;
    await pc?.close();
  }
}

/// The offer has no video codec this camera can encode in hardware.
class UnsupportedCodecError implements Exception {
  @override
  String toString() => 'UnsupportedCodecError';
}
