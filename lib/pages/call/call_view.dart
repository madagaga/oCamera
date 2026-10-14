import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/call/call_controller.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/theme/app_theme.dart';

/// Live view: full-screen video, translucent bars hidden after 4 s.
class CallView extends GetView<CallController> {
  const CallView({super.key});

  static const _chrome = AppTheme.videoChrome;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        await controller.hangup();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.toggleControls,
              onDoubleTap: controller.resetZoom,
              // No InteractiveViewer: the video texture is not drawn inside it
              // (black screen) on the tested devices.
              // RTCVideoView picks "texture or empty" only once at
              // construction: rebuild it on every renderer change,
              // otherwise it may stay empty (black screen) if the stream arrives later.
              child: InteractiveViewer(
                transformationController: controller.zoom,
                minScale: 1.0,
                maxScale: 4.0,
                child: RepaintBoundary(
                  key: controller.videoRenderKey,
                  // RTCVideoView picks "texture or empty" only once at its
                  // construction: rebuild it on every renderer change,
                  // otherwise it may stay empty (black screen).
                  child: ValueListenableBuilder<RTCVideoValue>(
                    valueListenable: controller.remoteRTCVideoRenderer,
                    builder: (_, __, ___) =>
                        RTCVideoView(controller.remoteRTCVideoRenderer),
                  ),
                ),
              ),
            ),
            Obx(() => controller.connected.value ||
                    controller.error.value.isNotEmpty
                ? const SizedBox.shrink()
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('Connecting…',
                            style: TextStyle(color: Color(0xFFE6E9EB))),
                      ],
                    ),
                  )),
            SafeArea(
              child: Stack(
                children: [
                  Obx(() => _fade(
                      visible: controller.controlsVisible.value ||
                          controller.error.value.isNotEmpty,
                      child: _topBar(oc))),
                  Obx(() => _badge()),
                  Obx(() => controller.error.value.isEmpty
                      ? const SizedBox.shrink()
                      : _errorBanner(context)),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Obx(() => _fade(
                        visible: controller.controlsVisible.value &&
                            controller.error.value.isEmpty,
                        child: _controlBar())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fade({required bool visible, required Widget child}) =>
      AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(ignoring: !visible, child: child),
      );

  Widget _topBar(OcamColors oc) => Container(
        height: 64,
        padding: const EdgeInsets.only(left: 4, right: 12),
        color: _chrome,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to cameras',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => controller.hangup(),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (controller.target.value.isPhone) ...[
                      const Icon(Icons.smartphone,
                          size: 15, color: Color(0xFFC9D0D4)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(controller.target.value.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  Text(
                    controller.connected.value
                        ? 'LIVE · ${controller.elapsed.value}'
                        : 'Connecting…',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFC9D0D4)),
                  ),
                ],
              ),
            ),
            _qualityMenu(),
          ],
        ),
      );

  /// SD / HD switch, shown when the camera offers several streams.
  Widget _qualityMenu() {
    final d = controller.target.value;
    if (d.caps.streams.length < 2) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Quality',
      onSelected: controller.changeStream,
      itemBuilder: (_) => [
        for (final name in d.caps.streams)
          CheckedPopupMenuItem(
            value: name,
            checked: name == d.activeStream,
            child: Text(streamLabel(name)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0x66FFFFFF)),
            borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(streamLabel(d.activeStream ?? d.caps.streams.first),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
        ]),
      ),
    );
  }

  Widget _badge() {
    final label = controller.linkLabel.value;
    if (label.isEmpty || !controller.connected.value) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 12,
      top: controller.controlsVisible.value ? 76 : 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xA60A0C0E),
            borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(controller.relayed.value ? Icons.alt_route : Icons.arrow_right_alt,
              size: 14, color: const Color(0xFFE6E9EB)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE6E9EB))),
        ]),
      ),
    );
  }

  Widget _errorBanner(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      top: 76,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        decoration: BoxDecoration(
            color: const Color(0xFF5C1A14),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFFDAD6), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stream stopped',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      Text(controller.error.value,
                          style: const TextStyle(color: Color(0xFFFFDAD6))),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDAD6),
                    foregroundColor: const Color(0xFF410E0B)),
                onPressed: () => controller.hangup(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Earpiece / loudspeaker / no sound selector.
  Widget _audioMenu() {
    IconData icon(AudioOutput o) => switch (o) {
          AudioOutput.earpiece => Icons.phone_in_talk,
          AudioOutput.speaker => Icons.volume_up,
          AudioOutput.off => Icons.volume_off,
        };
    String label(AudioOutput o) => switch (o) {
          AudioOutput.earpiece => 'Earpiece',
          AudioOutput.speaker => 'Loudspeaker',
          AudioOutput.off => 'No sound',
        };
    return Obx(() {
      final current = controller.audioOutput.value;
      return PopupMenuButton<AudioOutput>(
        tooltip: 'Audio output',
        onOpened: controller.showControls,
        onSelected: (o) {
          controller.showControls();
          controller.setAudioOutput(o);
        },
        itemBuilder: (_) => [
          for (final o in AudioOutput.values)
            CheckedPopupMenuItem(
              value: o,
              checked: o == current,
              child: Row(children: [
                Icon(icon(o), size: 20),
                const SizedBox(width: 12),
                Text(label(o)),
              ]),
            ),
        ],
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: Color(0x1FFFFFFF), shape: BoxShape.circle),
          child: Icon(icon(current), color: Colors.white),
        ),
      );
    });
  }

  Widget _controlBar() {
    Widget round(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          iconSize: 24,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x1FFFFFFF),
            fixedSize: const Size(56, 56),
          ),
          color: Colors.white,
          icon: Icon(icon),
          onPressed: () {
            controller.showControls();
            onTap();
          },
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: _chrome, borderRadius: BorderRadius.circular(40)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _audioMenu(),
          if (controller.canFlip)
            round(Icons.cameraswitch_outlined, 'Flip camera',
                controller.remoteSwitchCamera),
          if (controller.canToggleVideo)
            Obx(() => round(
                controller.enableVideo.value
                    ? Icons.videocam
                    : Icons.videocam_off,
                'Toggle video',
                controller.toggleVideo)),
          IconButton(
            tooltip: 'Hang up',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFC5221F),
              fixedSize: const Size(80, 56),
            ),
            color: Colors.white,
            iconSize: 28,
            icon: const Icon(Icons.call_end),
            onPressed: () => controller.hangup(),
          ),
        ],
      ),
    );
  }
}
