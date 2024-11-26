import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc/pages/call/call_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CallView extends GetView<CallController> {
  const CallView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) async {
          controller.hangup();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Obx(
                () => Text(
                    "${controller.isIncomingCall ? 'Call from' : 'Calling'} : ${controller.target.value.name}"),
              )),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: const EdgeInsets.all(20),
                    panEnabled: true,
                    scaleEnabled: true,
                    child: RepaintBoundary(
                      key: controller.videoRenderKey,
                      child: RTCVideoView(
                        controller.remoteRTCVideoRenderer,
//                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
                Obx(() => Visibility(
                    visible: !controller.connected.value,
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ))),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Obx(() => Visibility(
                      visible: controller.connected.value,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.call_end),
                            iconSize: 30,
                            color: Colors.redAccent,
                            onPressed: controller.hangup,
                          ),
                          if (controller.enableVideoButton)
                            IconButton(
                              icon: const Icon(Icons.cameraswitch),
                              color: Colors.white,
                              onPressed: controller.remoteSwitchCamera,
                            ),
                          Obx(() => IconButton(
                                icon: Icon(controller.enableAudio.value
                                    ? Icons.volume_up
                                    : Icons.volume_off),
                                color: Colors.white,
                                onPressed: controller.toggleAudio,
                              )),
                          if (controller.enableVideoButton)
                            Obx(() => IconButton(
                                  icon: Icon(controller.enableVideo.value
                                      ? Icons.videocam
                                      : Icons.videocam_off),
                                  color: Colors.white,
                                  onPressed: controller.toggleVideo,
                                )),
                        ],
                      ))),
                ),
              ],
            ),
          ),
        ));
  }

  // @override
  // void dispose() {
  //   _localRTCVideoRenderer.dispose();
  //   _remoteRTCVideoRenderer.dispose();
  //   _localStream?.dispose();
  //   _rtcPeerConnection?.dispose();
  //   super.dispose();
  // }
}
