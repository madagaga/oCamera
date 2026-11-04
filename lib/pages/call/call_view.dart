import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/call/call_controller.dart';
import 'package:rtc/pages/call/dock_menu.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/theme/app_theme.dart';

/// Shows the extra controls of the control bar: the audio output selector
/// (audio is muted by default) and the recording button. Hide them at build
/// time with `--dart-define=SHOW_EXTRA_CONTROLS=false`.
const bool kShowExtraControls =
    bool.fromEnvironment('SHOW_EXTRA_CONTROLS', defaultValue: true);

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
            Obx(() =>
                controller.connected.value || controller.error.value.isNotEmpty
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
                  Obx(() => _recIndicator()),
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

  /// Red "REC mm:ss" pill, shown as long as a recording runs, even when the
  /// controls are hidden.
  Widget _recIndicator() {
    if (!controller.recording.value) return const SizedBox.shrink();
    final s = controller.recordingSeconds.value;
    final t = '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
    return Positioned(
      left: 12,
      top: controller.controlsVisible.value ? 76 : 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xA60A0C0E),
            borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fiber_manual_record,
              size: 12, color: Color(0xFFFF5252)),
          const SizedBox(width: 6),
          Text('REC $t',
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE6E9EB))),
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
          Icon(
              controller.relayed.value
                  ? Icons.alt_route
                  : Icons.arrow_right_alt,
              size: 14,
              color: const Color(0xFFE6E9EB)),
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

  /// Output selector: the available outputs (Bluetooth or wired headset when
  /// connected, loudspeaker, earpiece), "No sound" and the volume boost, shown
  /// as a dock above the button.
  Widget _audioToggle() {
    IconData icon(String? id) => switch (id) {
          'bluetooth' => Icons.bluetooth_audio,
          'wired-headset' => Icons.headphones,
          'speaker' => Icons.volume_up,
          'earpiece' => Icons.phone_in_talk,
          _ => Icons.volume_off,
        };
    String label(String? id) => switch (id) {
          'bluetooth' => 'Bluetooth',
          'wired-headset' => 'Headphones',
          'speaker' => 'Loudspeaker',
          'earpiece' => 'Earpiece',
          _ => 'No sound',
        };
    return Obx(() => DockMenu(
          icon: icon(controller.audioDevice.value),
          tooltip: 'Audio output',
          barVisible: controller.controlsVisible,
          onTap: () {
            controller.showControls();
            controller.refreshAudioOutputs();
          },
          items: () {
            final current = controller.audioDevice.value;
            final gain = controller.audioGain.value;
            final levels = CallController.gainLevels;
            return [
              for (final id in [...controller.audioOutputs, 'off'])
                DockItem(
                  icon: icon(id == 'off' ? null : id),
                  label: label(id == 'off' ? null : id),
                  selected: id == (current ?? 'off'),
                  onTap: () =>
                      controller.setAudioDevice(id == 'off' ? null : id),
                ),
              // one entry that cycles x1 -> x2 -> x3 and stays open
              DockItem(
                text: 'x$gain',
                label: gain == 1 ? 'Volume x1' : 'Volume boost x$gain',
                keepOpen: true,
                onTap: () => controller.setAudioGain(
                    levels[(levels.indexOf(gain) + 1) % levels.length]),
              ),
            ];
          },
        ));
  }

  /// Video menu: switch camera or no video, as a dock above the button. The
  /// icon shows the camera in use when the camera announces it.
  Widget _videoMenu() {
    return Obx(() {
      final off = !controller.enableVideo.value;
      final icon = off
          ? Icons.videocam_off
          : switch (controller.facing.value) {
              'back' => Icons.camera_rear,
              'front' => Icons.camera_front,
              _ => Icons.videocam,
            };
      return DockMenu(
        icon: icon,
        tooltip: 'Video',
        barVisible: controller.controlsVisible,
        onTap: controller.showControls,
        items: () => [
          if (controller.canFlip)
            DockItem(
              icon: Icons.cameraswitch_outlined,
              label: 'Switch camera',
              onTap: () => controller.selectVideo('flip'),
            ),
          DockItem(
            icon: Icons.videocam_off,
            label: 'No video',
            selected: !controller.enableVideo.value,
            onTap: () => controller.selectVideo('off'),
          ),
        ],
      );
    });
  }

  Widget _controlBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: _chrome, borderRadius: BorderRadius.circular(40)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (kShowExtraControls) _audioToggle(),
          if (controller.canToggleVideo) _videoMenu(),
          if (kShowExtraControls)
            Obx(() => IconButton(
                  tooltip:
                      controller.recording.value ? 'Stop recording' : 'Record',
                  iconSize: 24,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x1FFFFFFF),
                    fixedSize: const Size(56, 56),
                  ),
                  color: controller.recording.value
                      ? Colors.white
                      : const Color(0xFFFF5252),
                  icon: Icon(controller.recording.value
                      ? Icons.stop
                      : Icons.fiber_manual_record),
                  onPressed: () {
                    controller.showControls();
                    controller.toggleRecording();
                  },
                )),
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
