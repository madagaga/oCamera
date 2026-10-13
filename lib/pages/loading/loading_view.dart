import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rtc/pages/loading/loading_controller.dart';
import 'package:rtc/theme/app_theme.dart';

class LoadingView extends GetView<LoadingController> {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: oc.accentContainer,
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.videocam_outlined,
                  size: 32, color: oc.onAccentContainer),
            ),
            const SizedBox(height: 24),
            const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 16),
            Text('Connecting…', style: TextStyle(color: oc.muted)),
          ],
        ),
      ),
    );
  }
}
