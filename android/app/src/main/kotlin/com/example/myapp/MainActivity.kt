package com.madagaga.ocamera

import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ocamera/codecs")
            .setMethodCallHandler { call, result ->
                if (call.method == "hardwareVideoEncoders") {
                    result.success(hardwareVideoEncoders())
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Lower-case names of the video codecs that have a hardware encoder. */
    private fun hardwareVideoEncoders(): List<String> {
        val byMime = mapOf(
            "video/avc" to "h264",
            "video/x-vnd.on2.vp8" to "vp8",
            "video/x-vnd.on2.vp9" to "vp9",
            "video/av01" to "av1",
            "video/hevc" to "h265",
        )
        val found = linkedSetOf<String>()
        for (info in MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos) {
            if (!info.isEncoder || !isHardware(info)) continue
            for (type in info.supportedTypes) {
                byMime[type.lowercase()]?.let { found.add(it) }
            }
        }
        return found.toList()
    }

    private fun isHardware(info: MediaCodecInfo): Boolean {
        if (Build.VERSION.SDK_INT >= 29) {
            return info.isHardwareAccelerated && !info.isSoftwareOnly && !info.isAlias
        }
        val name = info.name.lowercase()
        return !name.startsWith("omx.google.") && !name.startsWith("c2.android.") &&
            !name.contains(".sw.")
    }
}
