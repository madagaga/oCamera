import 'package:flutter_webrtc/flutter_webrtc.dart';
import './base_packet.dart';

class IcePacket extends BasePacket
{
    RTCIceCandidate iceCandidate = RTCIceCandidate('', '', 0);

    IcePacket(super.s, RTCIceCandidate pkt){
      iceCandidate = pkt;
    }
}