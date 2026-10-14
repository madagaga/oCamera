import 'package:get/get.dart';
import 'package:rtc/pages/camera/camera_controller.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(CameraController());
  }
}
