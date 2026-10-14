import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/camera/camera_controller.dart';
import 'package:rtc/theme/app_theme.dart';

/// Screen shown when this phone acts as a camera.
class CameraView extends GetView<CameraController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final s = controller.service;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: oc.accentContainer,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.smartphone, color: oc.onAccentContainer),
              ),
              const SizedBox(height: 16),
              const Text('Camera mode',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              Text(controller.name,
                  style: TextStyle(fontSize: 14, color: oc.muted)),
              const SizedBox(height: 32),
              Obx(() => _row(
                    context,
                    s.mqttConnected.value ? oc.online : oc.inUse,
                    s.mqttConnected.value
                        ? 'Connected to the broker'
                        : 'Reconnecting to the broker…',
                  )),
              const SizedBox(height: 12),
              Obx(() => _row(
                    context,
                    s.busy.value ? oc.online : oc.offline,
                    s.busy.value
                        ? 'Streaming to ${s.viewer.value ?? 'a viewer'}'
                        : 'Waiting for a viewer',
                  )),
              const Spacer(),
              Text(
                'You can turn the screen off. Keep this phone plugged in and '
                'allow the app to ignore battery optimization.',
                style: TextStyle(fontSize: 13, color: oc.muted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.stop,
                child: const Text('Stop camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Color dot, String text) => Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      );
}
