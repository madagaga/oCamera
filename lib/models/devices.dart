import 'dart:convert';
import 'dart:typed_data';

/// Capacités annoncées par une caméra (`caps` du message `state`).
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

/// Une caméra, reconstruite depuis `ocam/dev/{id}/state` (parsing tolérant).
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

  /// Met à jour l'appareil depuis un `state`. Si `caps` est absent, les
  /// dernières capacités connues sont conservées.
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

  /// Persistance locale (liste des appareils + dernier aperçu).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'caps': caps.toJson(),
        'agent': agent,
        'snapshot': base64Encode(snapshot),
      };

  /// Un appareil restauré est hors ligne tant que son `state` n'est pas reçu.
  factory Device.fromJson(Map<String, dynamic> j) {
    final d = Device(j['id'] as String, name: j['name'] as String?);
    d.kind = (j['kind'] as String?) ?? '';
    if (j['caps'] is Map<String, dynamic>) {
      d.caps = DeviceCaps.fromJson(j['caps'] as Map<String, dynamic>);
    }
    d.agent = j['agent'] as String?;
    final snap = j['snapshot'];
    if (snap is String && snap.isNotEmpty) d.snapshot = base64Decode(snap);
    return d;
  }
}
