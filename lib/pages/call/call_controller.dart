import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:get/get.dart';
import '../../models/action_packet.dart';
import '../../models/devices.dart';
import '../../models/ice_packet.dart';
import '../../models/sdp_packet.dart';
import '../../services/signaling_channel.dart';

class CallController extends GetxController {
  /// The associated Signaling service.
  final SignalingService _signalingService = Get.find();

  Rx<Device> target = Rx<Device>(Device('--', '---', '---', true));
  RxBool enableVideo = true.obs;
  RxBool enableAudio = true.obs;
  RxBool connected = false.obs;
  RxString error = ''.obs;

  bool isIncomingCall = false;
  bool enableVideoButton = false;
  bool hangedUp = false;

  final GlobalKey videoRenderKey = GlobalKey();

  webrtc.MediaStream? _localStream;
  webrtc.MediaStream? _remoteStream;
  webrtc.RTCPeerConnection? _rtcPeerConnection;
  final webrtc.RTCVideoRenderer remoteRTCVideoRenderer =
      webrtc.RTCVideoRenderer();

  final String bandwidth = '75';

  ///  The controller constructor.
  CallController();

  @override
  Future<void> onInit() async {
    _initializeSignaling();
    await _initializePeer();
    super.onInit();
  }

  @override
  void onClose() {
    hangup();
    remoteRTCVideoRenderer.dispose();
    super.dispose();
  }

  void _initializeArguments() {
    if (Get.arguments != null && Get.arguments is List) {
      List args = Get.arguments;
      if (args[0] is Device) {
        target.value = args[0];
        _createOffer();
      } else if (args[0] is SdpPacket) {
        target.value = args[1];
        isIncomingCall = true;
        _onOfferReceived(args[0]);
      }
    }
  }

  void _initializeSignaling() {
    _signalingService.onIceCandidateReceived = _onIceCandidateReceived;
    _signalingService.onActionReceived = _onActionReceived;
    _signalingService.onAnswerReceived = _onAnswerReceived;
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

  Future<void> _initializePeer() async {
    _rtcPeerConnection = await webrtc.createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    });

    _rtcPeerConnection!.onIceCandidate = (webrtc.RTCIceCandidate candidate) => {
          if (candidate.candidate != null)
            _signalingService.sendIceCandidate(target.value.id, candidate)
          else
            print("ice empty")
        };

    _rtcPeerConnection!.onConnectionState =
        (webrtc.RTCPeerConnectionState state) {
      print(' ********** $state');
      switch (state) {
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          break;
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          connected.value = true;
          enableVideoButton = !isIncomingCall && target.value.type != "sender";
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          hangup();
          break;
        default:
          break;
      }
    };

    _rtcPeerConnection!.onAddStream = (stream) {
      _remoteStream = stream;
      remoteRTCVideoRenderer.srcObject = _remoteStream;
      // enableVideoButton =
      //     !isIncomingCall.value && target.value.type != "sender";
    };

    _initializeArguments();
    await _initializeAudio();
  }

  webrtc.RTCSessionDescription setBandwidthLimit(
      webrtc.RTCSessionDescription packet) {
    if (packet.sdp!.contains('b=AS:')) {
      // insert b= after c= line.
      packet.sdp =
          packet.sdp!.replaceAllMapped(RegExp(r'c=IN (.*)\r\n'), (match) {
        return 'b=AS:$bandwidth\r\nc=IN ${match.group(1)}\r\n';
      });
    } else {
      packet.sdp =
          packet.sdp!.replaceAll(RegExp(r'b=AS:.*\r\n'), 'b=AS:$bandwidth\r\n');
    }
    return packet;
  }

  Future<void> _createOffer() async {
    await remoteRTCVideoRenderer.initialize();
    webrtc.RTCSessionDescription offer = await _rtcPeerConnection!.createOffer({
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true}
    });
    //offer = setBandwidthLimit(offer);

    await _rtcPeerConnection!.setLocalDescription(offer);
    _signalingService.sendSDP(target.value.id, offer);
  }

  void _onAnswerReceived(SdpPacket packet) async {
    await _rtcPeerConnection!.setRemoteDescription(packet.sdp);
  }

  void _onOfferReceived(SdpPacket packet) async {
// set SDP offer as remoteDescription for peerConnection
    await _rtcPeerConnection!.setRemoteDescription(
      packet.sdp,
    );

    // check if video should be enabled
    //enableVideo.value = packet.sdp.sdp!.contains('m=video');

    await _initializeStream();

    // create SDP answer
    webrtc.RTCSessionDescription answer =
        await _rtcPeerConnection!.createAnswer();

    //answer = setBandwidthLimit(answer);

    // set SDP answer as localDescription for peerConnection
    _rtcPeerConnection!.setLocalDescription(answer);

    _signalingService.sendSDP(target.value.id, answer);
  }

  void _onIceCandidateReceived(IcePacket packet) {
    // add iceCandidate
    if (_rtcPeerConnection != null) {
      _rtcPeerConnection!.addCandidate(packet.iceCandidate);
    }
  }

  Future<void> _initializeStream() async {
    Map<String, dynamic> config = {
      'video': {
        'width': 640,
        'height': 480,
        'facingMode': 'user',
        'frameRate': 10
      },
      'audio': {
        'mandatory': {
          'noiseSuppression': false,
          'echoCancellation': false,
          'autoGainControl': false
        }
      }
    };

    if (!enableVideo.value) {
      config['video'] = false;
    }

    // get localStream
    _localStream = await webrtc.navigator.mediaDevices.getUserMedia(config);

    // add mediaTrack to peerConnection
    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });
  }

  void hangup() {
    if (hangedUp) return;

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      _localStream!.dispose();
      _localStream = null;
    }

    if (_remoteStream != null) {
      captureSnapshot().then((onValue) {
        _remoteStream!.getTracks().forEach((track) {
          track.stop();
        });
        _remoteStream!.dispose();
        _remoteStream = null;
      });
    }

    if (_rtcPeerConnection != null) {
      _rtcPeerConnection!.close();
      _rtcPeerConnection = null;
    }
    if (target.value.id != '') {
      _signalingService.hangup(target.value.id);
    }

    //remoteRTCVideoRenderer.dispose();
    connected.value = false;
    hangedUp = true;
    Get.back();
  }

  void _onActionReceived(ActionPacket packet) {
    switch (packet.data['type']) {
      case 'hangup':
        hangup();
        break;
      case 'flipCamera':
        switchCamera();
        break;
      case 'toggleCamera':
        toggleVideo();
        break;
      case 'error':
        error.value = packet.data['message'];
        break;
    }
  }

  void switchCamera() {
// switch camera
    _localStream?.getVideoTracks().forEach((track) {
      webrtc.Helper.switchCamera(track);
    });
  }

  void toggleVideo() {
    // change status
    enableVideo.value = !enableVideo.value;
    // enable or disable video track
    _remoteStream?.getVideoTracks().forEach((track) {
      track.enabled = enableVideo.value;
    });
  }

  void remoteSwitchCamera() {
    _signalingService.flipCamera(target.value.id);
  }

  void toggleAudio() {
    enableAudio.value = !enableAudio.value;
    // enable or disable video track
    _remoteStream?.getAudioTracks().forEach((track) {
      track.enabled = enableAudio.value;
    });
  }

  Future<void> captureSnapshot() async {
    try {
      if (videoRenderKey.currentContext != null) {
        RenderRepaintBoundary boundary = videoRenderKey.currentContext!
            .findRenderObject() as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        // Save the image to the device's documents directory
        target.value.snapshot = pngBytes;
        print('Snapshot saved');
      } else {
        print('VideoRenderKey is not set or context is null');
      }
    } catch (e) {
      print('Error capturing snapshot: $e');
    }
  }
}
