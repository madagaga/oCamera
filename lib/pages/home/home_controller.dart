import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/models/sdp_packet.dart';
import 'package:rtc/models/user.dart';
import 'package:rtc/routes/app_pages.dart';
import 'package:rtc/services/signaling_channel.dart';

class HomeController extends GetxController {
  RxMap<String, Device> devices = RxMap<String, Device>(Get.find());

  /// The associated Signaling service.
  SignalingService signalingService = Get.find();
  User currentUser = Get.find();

  ///  The controller constructor.
  HomeController() {
    signalingService.onNewDeviceFound = _onNewDeviceFound;
    signalingService.onOfferReceived = _onOfferReceived;
    getDevices();
  }

@override
Future<void> onInit () async {
    final storage = GetStorage();
    storage.write('devices', jsonEncode(devices.toJson()));
    super.onInit();
  }

  void disconnect() {
    final storage = GetStorage();
    storage.erase().then((value) {
      Get.offAndToNamed(Routes.LOADING);
    });
  }

  void _onNewDeviceFound(Device d) {
    // if devive is new add
    if (!devices.containsKey(d.id)) {
      devices[d.id] = d;
    } else {
      devices[d.id]?.online = d.online;
      devices[d.id]?.streaming = d.streaming;
    }
  }

  void _onOfferReceived(SdpPacket packet) {
    Device target = Device(packet.source, packet.source, 'unknown', false);
    if (devices.containsKey(packet.source)) {
      target = devices[packet.source]!;
    }

    Get.toNamed(Routes.CALL, arguments: [packet, target]);
  }

  void getDevices() {
    signalingService.getDevices();
  }

  void videoCall(Device target) {
    Get.toNamed(Routes.CALL, arguments: [target]);
  }

  void audioCall(Device target) {
    Get.toNamed(Routes.CALL, arguments: [target]);
  }
}
