class User {
  String id = '';
  String name = '';
  String password = '';
  String broker = '';
  String deviceName = '';

  /// `viewer` (watches cameras) or `camera` (this phone is a camera).
  String role = 'viewer';

  bool get isCamera => role == 'camera';

  User();

  User.fromJson(Map<String, dynamic> data) {
    name = data['name'] ?? '';
    // a viewer's id is its MQTT username
    id = name;
    password = data['password'] ?? '';
    broker = data['broker'] ?? '';
    deviceName = data['deviceName'] ?? '';
    role = data['role'] == 'camera' ? 'camera' : 'viewer';
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'id': id, 'password': password, 'broker': broker, 'deviceName': deviceName, 'role': role};

  bool isValid() {
    if (id.isEmpty || name.isEmpty || password.isEmpty || broker.isEmpty) {
      return false;
    }
    // if broker is not url return false, use Uri.parse
    try {
      Uri.parse(broker);
    } catch (e) {
      return false;
    }

    return true;
  }
}
