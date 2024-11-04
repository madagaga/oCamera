import 'package:flutter_webrtc/flutter_webrtc.dart';
import './base_packet.dart';

class SdpPacket extends BasePacket {
  
  SdpPacket(super.s, RTCSessionDescription pkt) {
    sdp = pkt;
  }

  RTCSessionDescription sdp = RTCSessionDescription('', '');
}