import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';

class LoginController extends GetxController {
  User userData = Get.find();

  ///  The controller constructor.
  LoginController();

  Future<void> saveUserData(String name, String password, String broker) async {
    final storage = GetStorage();
    userData.id = DateTime.now().millisecondsSinceEpoch.toString();
    userData.name = name;
    userData.password = password;
    userData.broker = broker;

    await storage.write('currentUser', jsonEncode(userData.toJson()));
    Get.offAndToNamed(Routes.LOADING);
  }
}
