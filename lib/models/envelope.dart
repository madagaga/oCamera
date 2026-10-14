/// Envelope of `in` messages (MQTT_PROTOCOL.md § 4).
class Envelope {
  static const int version = 1;

  final int v;
  final int ts;
  final String? sid;
  final String type;
  final Map<String, dynamic> data;

  Envelope(this.type, this.data, {this.sid, int? ts})
      : v = version,
        ts = ts ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Envelope._(this.v, this.ts, this.sid, this.type, this.data);

  /// Returns `null` if the message is not a usable envelope.
  static Envelope? tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final v = json['v'], ts = json['ts'], type = json['type'];
    if (v is! int || ts is! int || type is! String) return null;
    final data = json['data'];
    final sid = json['sid'];
    return Envelope._(v, ts, sid is String ? sid : null, type,
        data is Map<String, dynamic> ? data : const {});
  }

  /// Tolerated gap between the local clock and `ts`: 30 s.
  bool get isFresh {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - ts).abs() <= 30;
  }

  Map<String, dynamic> toJson() => {
        'v': v,
        'ts': ts,
        if (sid != null) 'sid': sid,
        'type': type,
        'data': data,
      };
}
