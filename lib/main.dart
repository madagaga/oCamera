import 'dart:convert';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/pages/loading/loading_controller.dart';
import 'package:rtc/services/signaling_channel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await _initializePermissions();
  await _initializeServices();

  runApp(const OcameraApp());
}

Future<void> _initializePermissions() async {
  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.notification.request();
}

/// This function initializes all services used in the application.
Future _initializeServices() async {
  final storage = GetStorage();
  String? data = storage.read<String>('currentUser');
  // load user
  User currentUser = User();
  if (data != null) {
    dynamic jsonData = jsonDecode(data);
    currentUser = User.fromJson(jsonData);
  }
  Get.put(currentUser, permanent: true);

  Map<String, Device> devices = {};

  if (currentUser.id != '') {
    // load devices
    data = storage.read<String>('devices');
    if (data != null) {
      dynamic jsonData = jsonDecode(data);
      for (var item in jsonData) {
        devices[item['id']] = Device.fromJson(item, true);
      }
    }
  }
  Get.put(devices, permanent: true);

  Get.put(SignalingService(), permanent: true);
}

class OcameraApp extends StatefulWidget {
  const OcameraApp({super.key});

  @override
  _AppState createState() => _AppState();
}

/// This class represents the widget which is the root of your application.
class _AppState extends State<OcameraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add the observer
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove the observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      // Send a specific message before the app closes or goes into the background
      Get.find<SignalingService>().heartBeat(false);
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      onReady: () => Get.find<LoadingController>().initNaviationListener(),
      color: Colors.white,
      debugShowCheckedModeBanner: false,
      enableLog: true,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}
