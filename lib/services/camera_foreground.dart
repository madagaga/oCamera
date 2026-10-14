import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Android foreground service for camera mode.
///
/// It does no work itself: it keeps the process (hence the camera,
/// the microphone and the MQTT connection, which live in the main isolate)
/// alive with the screen off. It must be started from the visible app: Android 11+
/// only allows background camera access for a service started that way.
@pragma('vm:entry-point')
void cameraForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') FlutterForegroundTask.sendDataToMain('stop');
  }
}

class CameraForeground {
  static const _serviceId = 4210;

  /// Call once at app startup (before `runApp`).
  static void initPort() => FlutterForegroundTask.initCommunicationPort();

  static void _init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ocamera_camera',
        channelName: 'Camera mode',
        channelDescription: 'Shown while this phone acts as a camera.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Notification (Android 13+) and battery optimization exemption.
  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> start(String cameraName) async {
    _init();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [
        ForegroundServiceTypes.camera,
        ForegroundServiceTypes.microphone,
      ],
      notificationTitle: 'Camera active',
      notificationText: '$cameraName is available to your viewers',
      notificationButtons: const [NotificationButton(id: 'stop', text: 'Stop')],
      callback: cameraForegroundCallback,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// The notification's "Stop" button lands here.
  static void listenStop(void Function() onStop) {
    FlutterForegroundTask.addTaskDataCallback(_cb = (data) {
      if (data == 'stop') onStop();
    });
  }

  static void Function(Object)? _cb;

  static void unlistenStop() {
    final cb = _cb;
    if (cb != null) FlutterForegroundTask.removeTaskDataCallback(cb);
    _cb = null;
  }
}
