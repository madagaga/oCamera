import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/signaling_channel.dart';
import 'package:rtc/services/storage_service.dart';

class HomeController extends GetxController {
  RxMap<String, Device> devices = RxMap<String, Device>(Get.find());

  /// The associated Signaling service.
  SignalingService signalingService = Get.find();
  StorageService storageService = Get.find();
  User currentUser = Get.find();

  ///  The controller constructor.
  HomeController() {
    // states already received are replayed on subscription
    signalingService.onDeviceState = _onDeviceState;
  }

  @override
  void onClose() {
    signalingService.onDeviceState = null;
    super.onClose();
  }

  /// Saves the list (called when returning from a call, for the preview).
  void saveDevices() {
    storageService.saveDevices(devices);
    devices.refresh();
  }

  void disconnect() {
    signalingService.disconnect();
    GetStorage().erase().then((value) {
      Get.offAndToNamed(Routes.LOADING);
    });
  }

  void _onDeviceState(String id, Map<String, dynamic>? state) {
    if (id == signalingService.selfId) return;
    if (state == null) {
      // empty payload: the administrator removed the device
      devices.remove(id);
    } else {
      devices.putIfAbsent(id, () => Device(id)).applyState(state);
    }
    devices.refresh();
    storageService.saveDevices(devices);
  }

  Future<void> videoCall(Device target) async {
    await Get.toNamed(Routes.CALL, arguments: [target]);
    saveDevices();
  }
}
