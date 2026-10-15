import 'package:get/get.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/camera_service.dart';
import 'package:rtc/services/signaling_channel.dart';

class LoadingController extends GetxController {
  /// The associated Signaling service.
  SignalingService signalingService = Get.find();

  User currentUser = Get.find();

  ///  The controller constructor.
  LoadingController() {
    // if user is set then login
    if (currentUser.isValid()) {
      if (currentUser.isCamera) {
        _startCamera();
      } else {
        signalingService.onConnected = _onConnected;
        signalingService.connect(currentUser);
      }
    }
  }

  /// This phone is a camera: sign in with the camera account, then the dedicated screen.
  Future<void> _startCamera() async {
    final ok = await Get.find<CameraService>().start(currentUser);
    Get.offAndToNamed(ok ? Routes.CAMERA : Routes.LOGIN);
  }

  void initNaviationListener() {
    if (!currentUser.isValid()) {
      Get.offAndToNamed(Routes.LOGIN);
    }
  }

  void _onConnected(bool connected) {
    if (connected) {
      Get.offAndToNamed(Routes.HOME);
    } else {
      Get.offAndToNamed(Routes.LOGIN);
    }
    signalingService.onConnected = null;
  }
}
