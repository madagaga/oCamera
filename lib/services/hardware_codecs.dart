import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Video codecs this phone can encode in hardware (lower-case: `h264`, `vp8`…).
///
/// Software encoders cost far more battery and heat, so the camera only
/// offers codecs listed here. The list comes from Android's MediaCodecList.
class HardwareCodecs {
  static const _channel = MethodChannel('ocamera/codecs');

  /// Safe default if the platform cannot answer: H.264 is the only codec the
  /// WebRTC stack never provides in software on Android.
  static const _fallback = ['h264'];

  static Future<List<String>> videoEncoders() async {
    try {
      final list = await _channel.invokeListMethod<String>('hardwareVideoEncoders');
      debugPrint('[Camera] hardware video encoders: $list');
      return list ?? _fallback;
    } catch (e) {
      debugPrint('[Camera] cannot list hardware encoders: $e');
      return _fallback;
    }
  }
}
