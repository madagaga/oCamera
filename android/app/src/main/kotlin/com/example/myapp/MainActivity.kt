package com.madagaga.ocamera

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * The Flutter engine is cached and not destroyed with the activity.
 *
 * Camera mode runs MQTT, the camera and WebRTC in the Dart isolate of this
 * engine; the foreground service only keeps the process alive. If the engine
 * died with the activity (back button, swipe from recents), the MQTT
 * connection would drop and the camera would show up offline until the app is
 * reopened.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val ENGINE_ID = "ocamera_main"
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { return it }

        val engine = FlutterEngine(context.applicationContext)
        GeneratedPluginRegistrant.registerWith(engine)
        registerCodecChannel(engine)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        cache.put(ENGINE_ID, engine)
        return engine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    private fun registerCodecChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "ocamera/codecs")
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
