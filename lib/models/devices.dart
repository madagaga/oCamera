import 'dart:typed_data';

class Device {
  String id = '';
  String name = '';
  String type = '';
  bool online = false;
  Uint8List snapshot = Uint8List(0);

  Device(this.id, this.name, this.type, this.online);
  Map toJson() => {
        'name': name,
        'id': id,
        'type': type,
        'online': online,
      };

  Device.fromJson(Map<String, dynamic> data) {
    id = data['id'];
    name = data['name'];
    online = data['online'];
    type = data['type'];
  }
}
