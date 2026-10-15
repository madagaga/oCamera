/// Optional ICE configuration (`ocam/config/ice`).
class IceConfig {
  /// Default public STUN, without credentials.
  static const List<Map<String, dynamic>> defaultServers = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ]
    }
  ];

  final List<Map<String, dynamic>> servers;
  const IceConfig(this.servers);

  /// Returns `null` if the message is missing, empty or invalid.
  static IceConfig? tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final servers = <Map<String, dynamic>>[];

    final stun = json['stun'];
    if (stun is List) {
      final urls = stun.whereType<String>().toList();
      if (urls.isNotEmpty) servers.add({'urls': urls});
    }

    final turn = json['turn'];
    if (turn is Map<String, dynamic>) {
      final raw = turn['urls'];
      final urls = raw is List
          ? raw.whereType<String>().toList()
          : raw is String
              ? [raw]
              : <String>[];
      if (urls.isNotEmpty) {
        final entry = <String, dynamic>{'urls': urls};
        // username / credential optional
        if (turn['username'] is String) entry['username'] = turn['username'];
        if (turn['credential'] is String) {
          entry['credential'] = turn['credential'];
        }
        servers.add(entry);
      }
    }
    return servers.isEmpty ? null : IceConfig(servers);
  }
}
