# oCamera patch of flutter_webrtc 1.6.2+hotfix.4

Local copy used through `dependency_overrides` in `pubspec.yaml`. Only one thing
differs from the published plugin: the recording bitrate can be chosen.

Without a bitrate, the Android recorder tries 6 Mb/s first, which produced about
1.7 Mb/s (750 MB per hour) on a 640x360 stream. The app now asks for 120, 250 or
500 kb/s (`lib/models/recording_quality.dart`).

Changed files (search for "oCamera patch"):
- `android/.../MethodCallHandlerImpl.java`: reads the optional `bitrate` and `frameRate` arguments of `startRecordToFile`
- `android/.../GetUserMediaImpl.java`: passes them to the recorder
- `android/.../record/MediaRecorderImpl.java`: keeps them
- `android/.../record/VideoFileRenderer.java`: uses only the requested bitrate and frame rate when given, forces constant bitrate (CBR) when the encoder supports it (the variable mode overshot by about 45 %), and one key frame every 10 s instead of 5
- `lib/src/native/media_recorder_impl.dart`: `MediaRecorderNative(bitrate:, frameRate:)`
- `lib/flutter_webrtc.dart`: exports `MediaRecorderNative`

To go back to the published plugin: delete the `dependency_overrides` block in
`pubspec.yaml`, stop using `MediaRecorderNative` in `call_controller.dart`, and
remove this folder. To update the plugin: copy the new version and re-apply the
changes above.
