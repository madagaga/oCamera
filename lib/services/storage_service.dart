import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/models/user.dart';

/// All values are stored as JSON strings.
class StorageService {
  final storage = GetStorage();

  User loadUser() {
    final data = storage.read<String>('currentUser');
    if (data != null) {
      try {
        return User.fromJson(jsonDecode(data) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Storage] invalid user data: $e');
      }
    }
    return User();
  }

  void saveUser(User u) {
    storage.write('currentUser', jsonEncode(u.toJson()));
  }

  Map<String, Device> loadDevices() {
    final devices = <String, Device>{};
    final data = storage.read<String>('devices');
    if (data != null) {
      try {
        for (final item in jsonDecode(data) as List) {
          final d = Device.fromJson(item as Map<String, dynamic>);
          devices[d.id] = d;
        }
      } catch (e) {
        debugPrint('[Storage] invalid devices data: $e');
      }
    }
    return devices;
  }

  void saveDevices(Map<String, Device> devices) {
    storage.write(
        'devices', jsonEncode(devices.values.map((d) => d.toJson()).toList()));
  }
}
