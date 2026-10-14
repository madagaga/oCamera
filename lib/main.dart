import 'package:permission_handler/permission_handler.dart';
import 'package:rtc/pages/loading/loading_controller.dart';
import 'package:rtc/services/camera_foreground.dart';
import 'package:rtc/services/camera_service.dart';
import 'package:rtc/services/signaling_channel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/services/storage_service.dart';

import 'routes/app_pages.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CameraForeground.initPort();
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
  StorageService storageService = StorageService();

  // load user
  Get.put(storageService.loadUser(), permanent: true);

  Get.put(storageService.loadDevices(), permanent: true);

  Get.put(storageService, permanent: true);
  final signaling = SignalingService();
  Get.put(signaling, permanent: true);
  Get.put(CameraService(signaling), permanent: true);
}

/// Root of the application. A viewer does not announce its presence
/// (protocol v1), so there is no lifecycle handling here.
class OcameraApp extends StatelessWidget {
  const OcameraApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      onReady: () => Get.find<LoadingController>().initNaviationListener(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // dark by default, light as an option (home menu)
      themeMode: GetStorage().read<String>('theme') == 'light'
          ? ThemeMode.light
          : ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      enableLog: true,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}

