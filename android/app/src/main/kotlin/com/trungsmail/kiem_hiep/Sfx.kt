package com.trungsmail.kiem_hiep

import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Handler
import android.os.HandlerThread
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sound effects on a SoundPool of our own, driven from a background thread
 * (1.12.0). audioplayers' low-latency mode stopped and resumed its SoundPool
 * players on the main thread for every effect; SoundPool takes a lock that
 * its own stream thread holds while starting a sound, so on a busy audio
 * server the main thread waited and Android reported "Input dispatching
 * timed out" (SoundPoolPlayer.pause, the top ANRs in Play Console). Here the
 * main thread only hands the call over and returns; a new stream per play
 * needs no stop, and SoundPool drops the oldest beyond [MAX_STREAMS].
 */
class Sfx {
    private val thread = HandlerThread("kh-sfx").apply { start() }
    private val handler = Handler(thread.looper)
    private var pool: SoundPool? = null
    private val ids = HashMap<String, Int>()
    private val ready = HashSet<Int>()

    private fun pool(): SoundPool = pool ?: SoundPool.Builder()
        .setMaxStreams(MAX_STREAMS)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
        .also { p ->
            p.setOnLoadCompleteListener { _, id, status -> if (status == 0) ready.add(id) }
            pool = p
        }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> {
                val name = call.argument<String>("n")
                val path = call.argument<String>("p")
                if (name != null && path != null) {
                    handler.post {
                        try {
                            ids[name] = pool().load(path, 1)
                        } catch (e: Exception) {
                            // Missing or unreadable file: that effect stays silent.
                        }
                    }
                }
                result.success(null)
            }
            "play" -> {
                val name = call.argument<String>("n")
                val volume = (call.argument<Double>("v") ?: 1.0).toFloat().coerceIn(0f, 1f)
                handler.post {
                    try {
                        val id = ids[name ?: return@post] ?: return@post
                        if (id in ready) pool?.play(id, volume, volume, 1, 0, 1f)
                    } catch (e: Exception) {
                    }
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        handler.post {
            try {
                pool?.release()
            } catch (e: Exception) {
            }
            pool = null
            thread.quitSafely()
        }
    }

    companion object {
        const val MAX_STREAMS = 10
    }
}
