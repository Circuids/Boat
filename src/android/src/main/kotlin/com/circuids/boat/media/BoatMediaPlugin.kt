package com.circuids.boat.media

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Media bus plugin: wires `com.circuids.boat/media` and
 * `com.circuids.boat/mediaEvents`.
 *
 * Disjoint from the voice plugin's channels. The only shared state is
 * [MediaSessionArbiter], which the voice plugin also acquires.
 */
class BoatMediaPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodsChannel: MethodChannel? = null
    private var eventsChannel: EventChannel? = null

    @Volatile
    private var eventsSink: EventChannel.EventSink? = null

    private var engine: MediaPlaybackEngine? = null
    private var ticker: MediaProgressTicker? = null
    private var wav: WavReader? = null

    private var state = STATE_IDLE
    private var sourceKind = SOURCE_NONE
    private var loop = false
    private var positionBytes = 0L
    private var durationMs = -1L
    private var pcmFormat: Triple<Int, Int, Int>? = null

    fun attach(messenger: BinaryMessenger) {
        methodsChannel = MethodChannel(messenger, CHANNEL_METHODS).also {
            it.setMethodCallHandler(this)
        }
        eventsChannel = EventChannel(messenger, CHANNEL_EVENTS).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventsSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventsSink = null
                }
            })
        }
        MediaSessionArbiter.onMediaStop = { stopInternal(emitPreempted = true) }
    }

    fun detach() {
        MediaSessionArbiter.onMediaStop = null
        stopInternal(emitPreempted = false)
        methodsChannel?.setMethodCallHandler(null)
        methodsChannel = null
        eventsChannel?.setStreamHandler(null)
        eventsChannel = null
        eventsSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "mediaStart" -> handleStart(call, result)
                "mediaStop" -> {
                    stopInternal(emitPreempted = false)
                    result.success(null)
                }
                "mediaPlayPcm" -> handlePlayPcm(call, result)
                "mediaPlayFile" -> handlePlayFile(call, result)
                "mediaPlayAsset" -> handlePlayAsset(call, result)
                "mediaPause" -> handlePause(result)
                "mediaResume" -> handleResume(result)
                "mediaSeek" -> handleSeek(call, result)
                "mediaSetVolume" -> handleSetVolume(call, result)
                "mediaFlush" -> {
                    engine?.flush()
                    result.success(null)
                }
                "mediaGetStatus" -> result.success(statusMap())
                else -> result.notImplemented()
            }
        } catch (e: WavReader.Companion.WavFormatException) {
            emitError("MEDIA_SOURCE_FAILED", e.message ?: "Unsupported WAV")
            result.error("MEDIA_SOURCE_FAILED", e.message, null)
        } catch (e: Exception) {
            emitError("MEDIA_SOURCE_FAILED", e.message ?: "Media failure")
            result.error("MEDIA_SOURCE_FAILED", e.message, null)
        }
    }

    // ── Handlers ──

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        if (state != STATE_IDLE && state != STATE_ERROR) {
            result.success(null) // idempotent while already started
            return
        }
        if (!MediaSessionArbiter.acquireMedia()) {
            result.error("MEDIA_BUSY", "Voice engine owns the audio session", null)
            return
        }
        try {
            val sampleRate = call.argument<Int>("sampleRate") ?: 48000
            val channelCount = call.argument<Int>("channelCount") ?: 2
            val bits = call.argument<Int>("bitsPerSample") ?: 16
            if (bits != 16) {
                MediaSessionArbiter.release(MediaSessionArbiter.Owner.MEDIA)
                result.error("MEDIA_FORMAT_MISMATCH", "Only 16-bit PCM is supported", null)
                return
            }
            pcmFormat = Triple(sampleRate, channelCount, bits)
            engine = MediaPlaybackEngine().also { it.create(sampleRate, channelCount) }
            ticker = MediaProgressTicker { emitProgress() }
            setState(STATE_LOADING)
            result.success(null)
        } catch (e: Exception) {
            MediaSessionArbiter.release(MediaSessionArbiter.Owner.MEDIA)
            setState(STATE_ERROR)
            result.error("MEDIA_START_FAILED", e.message, null)
        }
    }

    private fun handlePlayPcm(call: MethodCall, result: MethodChannel.Result) {
        val pcm = call.argument<ByteArray>("pcm")
        if (pcm == null) {
            result.error("MEDIA_FORMAT_MISMATCH", "pcm bytes required", null)
            return
        }
        val fmt = pcmFormat
        if (fmt == null) {
            result.error("MEDIA_INVALID_STATE", "mediaStart must be called first", null)
            return
        }
        val bytesPerFrame = fmt.second * (fmt.third / 8)
        if (pcm.isEmpty() || pcm.size % bytesPerFrame != 0) {
            result.error(
                "MEDIA_FORMAT_MISMATCH",
                "PCM length ${pcm.size} is not a multiple of frame size $bytesPerFrame",
                null
            )
            return
        }
        val eng = engine ?: run {
            result.error("MEDIA_INVALID_STATE", "mediaStart must be called first", null)
            return
        }
        closeWav()
        sourceKind = SOURCE_PCM
        durationMs = -1
        positionBytes = 0
        eng.write(pcm)
        eng.start()
        ticker?.start()
        setState(STATE_PLAYING)
        result.success(null)
    }

    private fun handlePlayFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("MEDIA_SOURCE_FAILED", "path required", null)
            return
        }
        playWav(path, call.argument<Boolean>("loop") ?: false, SOURCE_FILE, result)
    }

    private fun handlePlayAsset(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("assetKey")
        if (key == null) {
            result.error("MEDIA_SOURCE_FAILED", "assetKey required", null)
            return
        }
        val lookup = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(key)
        playWav(lookup, call.argument<Boolean>("loop") ?: false, SOURCE_ASSET, result)
    }

    private fun playWav(
        path: String,
        shouldLoop: Boolean,
        kind: String,
        result: MethodChannel.Result,
    ) {
        if (state == STATE_IDLE || state == STATE_ERROR) {
            result.error("MEDIA_INVALID_STATE", "mediaStart must be called first", null)
            return
        }
        val reader = WavReader.open(path)
        closeWav()
        wav = reader
        loop = shouldLoop
        sourceKind = kind
        positionBytes = 0
        durationMs = reader.durationMs

        // Output follows the source format — no conversion code anywhere.
        engine?.create(reader.sampleRate, reader.channelCount)
        engine?.start()
        ticker?.start()
        setState(STATE_PLAYING)
        pumpWav()
        result.success(null)
    }

    private fun handlePause(result: MethodChannel.Result) {
        if (state != STATE_PLAYING) {
            result.error("MEDIA_INVALID_STATE", "pause requires playing, was $state", null)
            return
        }
        ticker?.stop()
        engine?.pause()
        setState(STATE_PAUSED)
        result.success(null)
    }

    private fun handleResume(result: MethodChannel.Result) {
        if (state != STATE_PAUSED) {
            result.error("MEDIA_INVALID_STATE", "resume requires paused, was $state", null)
            return
        }
        engine?.resume()
        ticker?.start()
        setState(STATE_PLAYING)
        pumpWav()
        result.success(null)
    }

    private fun handleSeek(call: MethodCall, result: MethodChannel.Result) {
        val reader = wav
        if (reader == null) {
            result.error("MEDIA_INVALID_STATE", "seek requires a file or asset source", null)
            return
        }
        val positionMs = call.argument<Int>("positionMs") ?: 0
        val bytesPerMs = reader.sampleRate.toLong() * reader.channelCount * 2 / 1000
        positionBytes = (positionMs * bytesPerMs).coerceAtLeast(0)
        engine?.flush()
        pumpWav()
        result.success(null)
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
        engine?.setVolume(volume)
        result.success(null)
    }

    // ── WAV streaming ──

    /**
     * Feeds the WAV payload to the output in chunks. Called on play, resume,
     * and seek; the drain thread paces actual output.
     */
    private fun pumpWav() {
        val reader = wav ?: return
        val eng = engine ?: return
        val chunk = ByteArray(reader.sampleRate * reader.channelCount * 2 / 50) // ~20 ms
        while (true) {
            val read = reader.read(chunk, positionBytes, chunk.size)
            if (read <= 0) {
                if (loop) {
                    positionBytes = 0
                    continue
                }
                mainHandler.post {
                    if (state == STATE_PLAYING) {
                        ticker?.stop()
                        setState(STATE_COMPLETED)
                        emit(mapOf("type" to "mediaCompleted"))
                    }
                }
                return
            }
            positionBytes += read
            eng.write(if (read == chunk.size) chunk.copyOf() else chunk.copyOf(read))
        }
    }

    private fun closeWav() {
        wav?.close()
        wav = null
    }

    // ── Teardown ──

    private fun stopInternal(emitPreempted: Boolean) {
        ticker?.stop()
        ticker = null
        closeWav()
        engine?.release()
        engine = null
        pcmFormat = null
        sourceKind = SOURCE_NONE
        loop = false
        positionBytes = 0
        durationMs = -1
        MediaSessionArbiter.release(MediaSessionArbiter.Owner.MEDIA)
        if (emitPreempted) {
            setState(STATE_IDLE)
            emit(mapOf("type" to "mediaPreempted", "reason" to "voiceEngineStarted"))
        } else {
            setState(STATE_IDLE)
        }
    }

    // ── Events ──

    private fun setState(next: String) {
        if (state == next) return
        val previous = state
        state = next
        emit(mapOf("type" to "mediaStateChanged", "previous" to previous, "current" to next))
    }

    private fun emitProgress() {
        if (state != STATE_PLAYING) return
        val reader = wav
        val posMs = if (reader == null) 0L else {
            val bytesPerMs = reader.sampleRate.toLong() * reader.channelCount * 2 / 1000
            if (bytesPerMs <= 0) 0L else positionBytes / bytesPerMs
        }
        emit(
            mapOf(
                "type" to "mediaProgress",
                "positionMs" to posMs.toInt(),
                "durationMs" to durationMs.toInt(),
            )
        )
    }

    private fun emitError(code: String, message: String) {
        setState(STATE_ERROR)
        emit(mapOf("type" to "mediaError", "code" to code, "message" to message))
    }

    private fun emit(payload: Map<String, Any?>) {
        val sink = eventsSink ?: return
        mainHandler.post { sink.success(payload) }
    }

    private fun statusMap(): Map<String, Any?> {
        val reader = wav
        val posMs = if (reader == null) 0L else {
            val bytesPerMs = reader.sampleRate.toLong() * reader.channelCount * 2 / 1000
            if (bytesPerMs <= 0) 0L else positionBytes / bytesPerMs
        }
        return mapOf(
            "state" to state,
            "positionMs" to posMs.toInt(),
            "durationMs" to durationMs.toInt(),
            "volume" to (engine?.volume ?: 1.0f).toDouble(),
            "sourceKind" to sourceKind,
            "loop" to loop,
        )
    }

    companion object {
        const val CHANNEL_METHODS = "com.circuids.boat/media"
        const val CHANNEL_EVENTS = "com.circuids.boat/mediaEvents"

        private const val STATE_IDLE = "idle"
        private const val STATE_LOADING = "loading"
        private const val STATE_PLAYING = "playing"
        private const val STATE_PAUSED = "paused"
        private const val STATE_COMPLETED = "completed"
        private const val STATE_ERROR = "error"

        private const val SOURCE_NONE = "none"
        private const val SOURCE_PCM = "pcm"
        private const val SOURCE_FILE = "file"
        private const val SOURCE_ASSET = "asset"
    }
}
