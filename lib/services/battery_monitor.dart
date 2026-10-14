import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/battery_info.dart';

/// Tracks the phone battery and tells when it is worth publishing again.
///
/// Reading the battery is free (Android keeps the value in memory) and the
/// CPU is already held awake by the foreground service. What costs a little
/// is each MQTT publish, so [onChange] is only called when the charger is
/// plugged or unplugged, the level moved by at least 5 points, or the level
/// is at 20 % or below and changed at all.
class BatteryMonitor {
  BatteryMonitor(this.onChange);

  final void Function(BatteryInfo info) onChange;
  final Battery _battery = Battery();

  BatteryInfo? current;
  BatteryInfo? _published;
  StreamSubscription<BatteryState>? _sub;
  Timer? _timer;

  static const _poll = Duration(minutes: 5);

  Future<void> start() async {
    current = await _read();
    _published = current;
    _sub = _battery.onBatteryStateChanged.listen((_) => _refresh());
    _timer = Timer.periodic(_poll, (_) => _refresh());
  }

  void stop() {
    _sub?.cancel();
    _timer?.cancel();
    _sub = null;
    _timer = null;
  }

  Future<BatteryInfo?> _read() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final plugged = state == BatteryState.charging ||
          state == BatteryState.full ||
          state == BatteryState.connectedNotCharging;
      return BatteryInfo(level, plugged);
    } catch (e) {
      // no battery (e.g. a tablet on a dock) or the platform cannot tell
      debugPrint('[Camera] battery unavailable: $e');
      return null;
    }
  }

  Future<void> _refresh() async {
    final now = await _read();
    if (now == null) return;
    current = now;
    final prev = _published;
    final publish = prev == null ||
        now.charging != prev.charging ||
        (now.level - prev.level).abs() >= 5 ||
        (now.level <= 20 && now.level != prev.level);
    if (publish) {
      _published = now;
      onChange(now);
    }
  }
}
