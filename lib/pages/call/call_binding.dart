import 'package:get/get.dart';
import 'package:rtc/pages/call/call_controller.dart';


class CallBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      CallController(),
    );
  }
}