import 'dart:convert';
import 'dart:typed_data';

/// Capabilities announced by a camera (`caps` of the `state` message).
class DeviceCaps {
  final List<String> video;
  final List<String> audio;
  final List<String> streams;
  final List<String> cmds;

  const DeviceCaps({
    this.video = const [],
    this.audio = const [],
    this.streams = const [],
    this.cmds = const [],
  });

  static List<String> _strings(dynamic v) =>
      v is List ? v.whereType<String>().toList() : const [];

  factory DeviceCaps.fromJson(Map<String, dynamic> j) => DeviceCaps(
        video: _strings(j['video']),
        audio: _strings(j['audio']),
        streams: _strings(j['streams']),
        cmds: _strings(j['cmds']),
      );

  Map<String, dynamic> toJson() =>
      {'video': video, 'audio': audio, 'streams': streams, 'cmds': cmds};
}

/// A camera, rebuilt from `ocam/dev/{id}/state` (tolerant parsing).
class Device {
  String id;
  String name;
  bool online;
  bool busy;
  String? viewer;
  String kind;
  DeviceCaps caps;
  String? agent;
  Uint8List snapshot = Uint8List(0);

  /// Stream chosen by the user (`sub`, `main`…); null = camera default.
  String? stream;

  Device(this.id,
      {String? name,
      this.online = false,
      this.busy = false,
      this.viewer,
      this.kind = '',
      this.caps = const DeviceCaps(),
      this.agent})
      : name = name ?? id;

  bool get isPhone => kind == 'phone';

  /// Stream used by the next call: the user's choice, else the camera default.
  String? get activeStream =>
      stream ?? (caps.streams.isEmpty ? null : caps.streams.first);

  /// Updates the device from a `state`. If `caps` is missing, the
  /// last known capabilities are kept.
  void applyState(Map<String, dynamic> j) {
    final n = j['name'];
    if (n is String && n.isNotEmpty) name = n;
    online = j['online'] == true;
    busy = j['busy'] == true;
    viewer = j['viewer'] is String ? j['viewer'] as String : null;
    if (j['kind'] is String) kind = j['kind'] as String;
    if (j['caps'] is Map<String, dynamic>) {
      caps = DeviceCaps.fromJson(j['caps'] as Map<String, dynamic>);
    }
    final a = j['agent'];
    if (a is Map && a['name'] != null) {
      agent = '${a['name']} ${a['version'] ?? ''}'.trim();
    }
  }

  factory Device.fromState(String id, Map<String, dynamic> j) =>
      Device(id)..applyState(j);

  /// Local persistence (device list + last preview).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'caps': caps.toJson(),
        'agent': agent,
        'snapshot': base64Encode(snapshot),
        'stream': stream,
      };

  /// A restored device is offline until its `state` is received.
  factory Device.fromJson(Map<String, dynamic> j) {
    final d = Device(j['id'] as String, name: j['name'] as String?);
    d.kind = (j['kind'] as String?) ?? '';
    if (j['caps'] is Map<String, dynamic>) {
      d.caps = DeviceCaps.fromJson(j['caps'] as Map<String, dynamic>);
    }
    d.agent = j['agent'] as String?;
    d.stream = j['stream'] as String?;
    final snap = j['snapshot'];
    if (snap is String && snap.isNotEmpty) d.snapshot = base64Decode(snap);
    return d;
  }
}

/// Display name of a stream: `sub` = SD, `main` = HD.
String streamLabel(String name) => switch (name) {
      'sub' => 'SD',
      'main' => 'HD',
      _ => name.toUpperCase(),
    };
