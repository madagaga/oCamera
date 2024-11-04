class User {
  String id = '';
  String name = '';
  String password = '';
  String broker = '';

  User();

  User.fromJson(Map<String, dynamic> data) {
    id = data['id'];
    name = data['name'];
    password = data['password'];
    broker = data['broker'];
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'id': id, 'password': password, 'broker': broker};

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
