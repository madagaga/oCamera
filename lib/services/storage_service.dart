import 'dart:convert';

import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/models/user.dart';

class StorageService {
  final storage = GetStorage();

  User loadUser() {
    String? data = storage.read<String>('currentUser');
    User currentUser = User();
    if (data != null) {
      dynamic jsonData = jsonDecode(data);
      currentUser = User.fromJson(jsonData);
    }
    return currentUser;
  }

  void saveUser(User u) {
    storage.write('currentUser', u.toJson());
  }

  Map<String, Device> loadDevices() {
    Map<String, Device> devices = {};
    String? data = storage.read<String>('devices');
    if (data != null) {
      dynamic jsonData = jsonDecode(data);
      for (var item in jsonData) {
        devices[item['id']] = Device.fromJson(item, true);
      }
    }
    return devices;
  }

  void saveDevices(Map<String, Device> devices) {
    List<String> jsonDevices = [];
    for (var item in devices.values) {
      jsonDevices.add(jsonEncode(item.toJson(true)));
    }
    storage.write('devices', jsonDevices);
  }
}
