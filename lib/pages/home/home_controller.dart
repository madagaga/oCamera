import 'package:get/get.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/models/sdp_packet.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/signaling_channel.dart';

class HomeController extends GetxController {
  RxMap<String, Device> devices = <String, Device>{}.obs;

  /// The associated Signaling service.
  SignalingService signalingService = Get.find();
  User currentUser = Get.find();

  ///  The controller constructor.
  HomeController() {
    signalingService.onNewDeviceFound = _onNewDeviceFound;
    signalingService.onOfferReceived = _onOfferReceived;
  }

  void _onNewDeviceFound(Device d) {
    devices.addAll({d.id: d});
  }

  void _onOfferReceived(SdpPacket packet) {
    Device? target;
    if (devices.containsKey(packet.source)) {
      target = devices[packet.source]!;
    }
    Get.toNamed(Routes.CALL, arguments: [packet, target]);
  }

  void getDevices() {
    devices.clear();
    signalingService.getDevices();
  }

  void videoCall(Device target) {
    Get.toNamed(Routes.CALL, arguments: [target, true]);
  }

  void audioCall(Device target) {
    Get.toNamed(Routes.CALL, arguments: [target, false]);
  }
}
