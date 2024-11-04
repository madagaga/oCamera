import 'package:get/get.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/signaling_channel.dart';

class LoadingController extends GetxController {
  /// The associated Signaling service.
  SignalingService signalingService = Get.find();

  User currentUser = Get.find();

  ///  The controller constructor.
  LoadingController() {
    // if user is set then login
    if (currentUser.isValid()) {
      signalingService.onConnected = _onConnected;
      signalingService.connect(currentUser);
    }
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
