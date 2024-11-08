import 'dart:typed_data';

class Device {
  String id = '';
  String name = '';
  String type = '';
  bool online = false;
  bool streaming = false;
  Uint8List snapshot = Uint8List(0);

  Device(this.id, this.name, this.type, this.online);

  Map toJson(bool full) {
    Map<String, dynamic> result = {
      'name': name,
      'id': id,
      'type': type,
      'online': online,
      'streaming': streaming,
    };
    if (full) {
      result['snapshot'] = snapshot;
    }
    return result;
  }

  Device.fromJson(Map<String, dynamic> data, bool full) {
    id = data['id'];
    name = data['name'];
    online = data['online'];
    type = data['type'];
    // set streaming if available
    streaming = data['streaming'] ?? false;
    if (full) {
      snapshot = data['snapshot'] ?? Uint8List(0);
    }
  }
}
