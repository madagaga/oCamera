class User {
  String id = '';
  String name = '';
  String password = '';
  String broker = '';
  String deviceName = '';

  User();

  User.fromJson(Map<String, dynamic> data) {
    name = data['name'] ?? '';
    // l'identifiant d'un viewer est son nom d'utilisateur MQTT
    id = name;
    password = data['password'] ?? '';
    broker = data['broker'] ?? '';
    deviceName = data['deviceName'] ?? '';
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'id': id, 'password': password, 'broker': broker, 'deviceName': deviceName};

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
