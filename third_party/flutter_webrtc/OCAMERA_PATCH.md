# oCamera patch of flutter_webrtc 1.6.3

Local copy used through `dependency_overrides` in `pubspec.yaml`. It differs from
the published plugin in two independent ways:

1. the recording bitrate can be chosen (section "Recording bitrate");
2. thread-safety / deadlock fixes around `getTransceivers()` (section "Transceivers").

The full difference is in `ocamera.patch` (same folder), generated against the
pristine `flutter_webrtc-1.6.3` of the pub cache.

## Recording bitrate

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

## Transceivers: crash and deadlock fixes (Android)

File: `android/.../PeerConnectionObserver.java` (only this file).

Upstream calls `peerConnection.getTransceivers()` from two threads without any
protection: the main thread (Dart method calls) and the WebRTC signaling thread
(`onAddTrack`). The Java wrapper disposes the previous list on every call, so an
overlap throws `IllegalStateException` on a native thread and aborts the process
(SIGABRT). Two successive fixes:

**Fix 1 (2026-10, earlier session): `transceiversLock`.**
- `private final Object transceiversLock`, taken around every `getTransceivers()` use:
  `getRtpTransceiverById`, `getTransceivers(Result)`, `getTransceiversTrack`.
- Each use is wrapped in `try/catch (IllegalStateException)` that logs a warning
  (`... transceiver disposed concurrently`).
- Side effect found on 2026-11-04: the same lock was also taken in `onAddTrack`
  (signaling thread). The main thread holds the lock while its native
  `getTransceivers()` blocks on the signaling thread, which waits for the lock:
  lock-order deadlock. Logcat symptom: `W/warn_current_thread_is_deadlocked.cc:
  Probable deadlock` with `Java_org_webrtc_PeerConnection_nativeGetTransceivers`
  in the stack, right after `onAddTrack`.

**Fix 2 (2026-11-04): `onAddTrack` no longer takes the lock nor calls the native list.**
- New field `trackTransceivers` (`ConcurrentHashMap<String, RtpTransceiver>`, key =
  receiver id), filled by `onTrack(RtpTransceiver)` (empty upstream).
- `onAddTrack` reads that map. If `onTrack` has not fired yet, the `onTrack` event is
  sent without `transceiver` and `W/...: onAddTrack: no transceiver announced for
  receiver <id>` is logged (the Dart side treats the field as optional and the app
  does not use it).
- `transceivers` changed from `HashMap` to `ConcurrentHashMap` (now written from the
  signaling thread without the lock).

### What to check after a build
- No `Probable deadlock` after `onAddTrack`:
  `adb logcat | findstr /i "deadlock onAddTrack SIGABRT"`.
- The warning `no transceiver announced` should not appear. If it does, WebRTC fires
  `onAddTrack` before `onTrack`: the event must then be completed from `onTrack`.

## Comparing with a future build / plugin version
Regenerate the patch and compare it with the committed one:

```bash
O=~/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_webrtc-<version>
cd flutter_client/third_party/flutter_webrtc
diff -ruN --strip-trailing-cr -x .git -x build -x example -x OCAMERA_PATCH.md   -x ocamera.patch -x '*.iml' "$O" . > /tmp/new.patch
diff ocamera.patch /tmp/new.patch
```

To port the changes onto a new plugin version: copy that version over this folder,
then `patch -p1 < ocamera.patch` (from inside `third_party/flutter_webrtc`) and
fix the rejected hunks by hand.

Files touched in total (vs 1.6.3): `GetUserMediaImpl.java`,
`MethodCallHandlerImpl.java`, `PeerConnectionObserver.java`, `record/MediaRecorderImpl.java`,
`record/VideoFileRenderer.java`, `lib/flutter_webrtc.dart`,
`lib/src/native/media_recorder_impl.dart`.

## Rebase on 1.6.3 (2026-11-04)
The fork was rebased from 1.6.2+hotfix.4 onto 1.6.3 (upstream #2230 registers remote
tracks in `onAddTrack` via `remoteTracksByReceiver`, which fixes renderers going black after
`getTransceivers()`; it still calls `getTransceivers()` unlocked from the signaling thread, so
the `trackTransceivers` change is kept on top of it). Android libwebrtc bumped to 150.7871.04.

Extra changes made during the rebase (all in `PeerConnectionObserver.java` unless noted):
- `getRtpSenderById`, `getRtpReceiverById` and the loops of `getStatsForTrack` take
  `transceiversLock` and catch `IllegalStateException` (`getSenders()`/`getReceivers()` also
  dispose the previous list). All their callers are on the main thread.
- `restartIce()`, `close()` and `dispose()` tolerate a null `peerConnection`.
- `trackTransceivers` is cleared in `close()` and per receiver in `onRemoveTrack`.
- Tried and reverted: `Logging.enableLogToDebugOutput(LS_WARNING)` in `initialize()` throws
  `IllegalStateException: Logging to native debug output not supported while Loggable is
  injected` (the plugin injects its own `Loggable`), which made `WebRTC.initialize` fail.
  The libwebrtc INFO noise in logcat is left as is.
- Not changed: `AudioSwitchManager.start()` is already idempotent (`isActive` guard).
