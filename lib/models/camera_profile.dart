import 'devices.dart';

/// What a camera announces in its `state` (MQTT_PROTOCOL.md § 5).
class CameraProfile {
  final String name;
  final DeviceCaps caps;
  final String agentName;
  final String agentVersion;

  const CameraProfile({
    required this.name,
    required this.caps,
    this.agentName = 'ocamera-app',
    this.agentVersion = '1.0.0',
  });

  Map<String, dynamic> state(
      {bool online = true, bool busy = false, String? viewer}) {
    return {
      'v': 1,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'name': name,
      'online': online,
      'busy': busy,
      'viewer': viewer,
      'kind': 'phone',
      'caps': caps.toJson(),
      'agent': {'name': agentName, 'version': agentVersion},
    };
  }
}
