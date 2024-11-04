import './base_packet.dart';

class ActionPacket extends BasePacket {
  Map<String, dynamic> data = {};

  ActionPacket(super.s, Map<String, dynamic> pkt) {
    data = pkt;
  }
}
