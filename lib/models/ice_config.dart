/// Configuration ICE optionnelle (`ocam/config/ice`).
class IceConfig {
  /// STUN public par défaut, sans identifiants.
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

  /// Retourne `null` si le message est absent, vide ou invalide.
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
        // username / credential facultatifs
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
