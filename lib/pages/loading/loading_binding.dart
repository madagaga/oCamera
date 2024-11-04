import 'package:get/get.dart';
import 'package:rtc/pages/loading/loading_controller.dart';

class LoadingBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      LoadingController(),
    );
  }
}