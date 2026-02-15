import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';

class LoginController extends GetxController {
  User userData = Get.find();
  
  // Observable variables to hold user data
  final RxString name = ''.obs;
  final RxString password = ''.obs;
  final RxString broker = 'tls://1720f847e41a4e1e9e17e321e32ec831.s2.eu.hivemq.cloud:8883'.obs;
  final RxString deviceName = ''.obs;
  final RxBool userExists = false.obs;

  ///  The controller constructor.
  LoginController() {
    loadUserData();
  }
  
  @override
  void onInit() {
    super.onInit();
    loadUserData();
  }

  /// Loads user data from storage if it exists
  Future<void> loadUserData() async {
    final storage = GetStorage();
    final userJson = storage.read('currentUser');
    
    if (userJson != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        userData = User.fromJson(userMap);
        
        // Update the observable variables
        name.value = userData.name;
        password.value = userData.password;
        broker.value = userData.broker;
        deviceName.value = userData.deviceName;
        userExists.value = true;
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> saveUserData(
      String name, String password, String broker, String deviceName) async {
    final storage = GetStorage();
    userData.id = DateTime.now().millisecondsSinceEpoch.toString();
    userData.name = name;
    userData.password = password;
    userData.broker = broker;
    userData.deviceName = deviceName;

    await storage.write('currentUser', jsonEncode(userData.toJson()));
    Get.offAndToNamed(Routes.LOADING);
  }
}
