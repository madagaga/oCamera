/// Battery of a phone camera, announced in its `state` (MQTT_PROTOCOL.md § 5).
class BatteryInfo {
  /// 0 to 100.
  final int level;

  /// True when external power is connected (charging, or full on the charger).
  final bool charging;

  const BatteryInfo(this.level, this.charging);

  Map<String, dynamic> toJson() => {'level': level, 'charging': charging};

  /// Tolerant parsing: null if `level` is missing or out of range.
  static BatteryInfo? tryParse(dynamic json) {
    if (json is! Map) return null;
    final level = json['level'];
    if (level is! num || level < 0 || level > 100) return null;
    return BatteryInfo(level.round(), json['charging'] == true);
  }

  @override
  bool operator ==(Object other) =>
      other is BatteryInfo && other.level == level && other.charging == charging;

  @override
  int get hashCode => Object.hash(level, charging);
}
