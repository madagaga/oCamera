import 'package:get/get.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/camera_foreground.dart';
import 'package:rtc/services/camera_service.dart';

/// Camera mode screen: status + stop. The logic lives in [CameraService],
/// keep-alive in [CameraForeground].
class CameraController extends GetxController {
  final CameraService service = Get.find();
  final User user = Get.find();

  String get name => user.deviceName.isEmpty ? user.name : user.deviceName;

  @override
  Future<void> onInit() async {
    super.onInit();
    CameraForeground.listenStop(stop);
    await CameraForeground.requestPermissions();
    // started here, app visible: required to access the camera in the background
    await CameraForeground.start(name);
  }

  Future<void> stop() async {
    await service.stop();
    await CameraForeground.stop();
    Get.offAllNamed(Routes.LOGIN);
  }

  @override
  void onClose() {
    CameraForeground.unlistenStop();
    super.onClose();
  }
}
