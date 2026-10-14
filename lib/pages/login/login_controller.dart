import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/signaling_channel.dart';
import 'package:rtc/services/storage_service.dart';

class LoginController extends GetxController {
  User userData = Get.find();
  
  // Observable variables to hold user data
  final RxString name = ''.obs;
  final RxString password = ''.obs;
  final RxString broker = 'tls://1720f847e41a4e1e9e17e321e32ec831.s2.eu.hivemq.cloud:8883'.obs;
  final RxString deviceName = ''.obs;
  final RxString role = 'viewer'.obs;
  final RxBool userExists = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
  }

  /// Loads user data from storage if it exists
  Future<void> loadUserData() async {
    final userJson = GetStorage().read<String>('currentUser');

    if (userJson != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        // copy into the shared instance (Get.find) rather than replacing it
        final loaded = User.fromJson(userMap);
        userData.id = loaded.id;
        userData.name = loaded.name;
        userData.password = loaded.password;
        userData.broker = loaded.broker;
        userData.deviceName = loaded.deviceName;
        userData.role = loaded.role;

        // Update the observable variables
        name.value = userData.name;
        password.value = userData.password;
        broker.value = userData.broker;
        deviceName.value = userData.deviceName;
        role.value = userData.role;
        userExists.value = true;
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  // Connection test
  final RxBool testing = false.obs;
  final RxString testError = ''.obs;
  final RxInt testMs = (-1).obs; // -1: no positive result

  Future<void> testConnection(
      String broker, String name, String password) async {
    testing.value = true;
    testError.value = '';
    testMs.value = -1;
    final user = User()
      ..name = name
      ..id = name
      ..password = password
      ..broker = broker;
    int ms = -1;
    final error = await SignalingService.testConnection(user, (v) => ms = v);
    testing.value = false;
    if (error == null) {
      testMs.value = ms;
    } else {
      testError.value = error;
    }
  }

  Future<void> saveUserData(
      String name, String password, String broker, String role) async {
    userData.role = role;
    userData.name = name;
    userData.id = name;
    userData.password = password;
    userData.broker = broker;
    userData.deviceName = name;

    Get.find<StorageService>().saveUser(userData);
    Get.offAndToNamed(Routes.LOADING);
  }
}


