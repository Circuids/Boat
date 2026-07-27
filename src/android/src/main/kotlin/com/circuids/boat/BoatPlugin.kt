package com.circuids.boat

import android.content.Context
import com.circuids.boat.audio.*
import com.circuids.boat.pipeline.*
import com.circuids.boat.pipeline.stages.MetadataStage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BoatPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodsChannel: MethodChannel
    private lateinit var eventsChannel: EventChannel
    private lateinit var captureChannel: EventChannel

    private var eventsSink: EventChannel.EventSink? = null
    private var captureSink: EventChannel.EventSink? = null

    private var sessionManager: AudioSessionManager? = null
    private var captureEngine: AudioCaptureEngine? = null
    private var playbackEngine: AudioPlaybackEngine? = null
    private var effectsManager: EffectsManager? = null
    private var routeManager: AudioRouteManager? = null
    private var pipeline: PipelineRunner? = null
    private var publisher: FramePublisher? = null

    private var currentState = "idle"
    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        val messenger = binding.binaryMessenger

        methodsChannel = MethodChannel(messenger, "com.circuids.boat/methods")
        methodsChannel.setMethodCallHandler(this)

        eventsChannel = EventChannel(messenger, "com.circuids.boat/events")
        eventsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventsSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventsSink = null
            }
        })

        captureChannel = EventChannel(messenger, "com.circuids.boat/capture")
        captureChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                captureSink = events
            }
            override fun onCancel(arguments: Any?) {
                captureSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        teardown()
        methodsChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "start" -> handleStart(call, result)
            "stop" -> handleStop(result)
            "pause" -> handlePause(result)
            "resume" -> handleResume(result)
            "dispose" -> handleDispose(result)
            "reconfigure" -> handleReconfigure(call, result)
            "flushPlayback" -> handleFlushPlayback(result)
            "setRoute" -> handleSetRoute(call, result)
            "getDiagnostics" -> handleGetDiagnostics(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: Result) {
        try {
            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val sampleRate = (args["sampleRate"] as? Number)?.toInt() ?: 16000
            val bufferMs = (args["bufferDurationMs"] as? Number)?.toInt() ?: 20
            val enableAec = args["aec"] as? Boolean ?: true
            val enableAgc = args["agc"] as? Boolean ?: true
            val enableNs = args["noiseSuppression"] as? Boolean ?: true

            emitState("starting")

            val session = AudioSessionManager(appContext)
            session.activate()
            sessionManager = session

            val capture = AudioCaptureEngine(sampleRate, bufferMs)
            val sessionId = capture.create()
            captureEngine = capture

            val effects = EffectsManager()
            effects.attach(sessionId, enableAec, enableAgc, enableNs)
            effectsManager = effects

            val playback = AudioPlaybackEngine(sampleRate, sessionId)
            playback.create()
            playback.start()
            playbackEngine = playback

            val route = AudioRouteManager(appContext, session.audioManagerRef) { newRoute ->
                publisher?.emitRouteChanged(currentRouteName(), newRoute.channelName)
            }
            route.start()
            routeManager = route

            val pub = FramePublisher { captureSink }
            publisher = pub

            val config = PipelineConfig.fromMap(args.mapKeys { it.key.toString() })
            val metadataStage = MetadataStage { route.currentRoute.channelName }
            // CapturePipeline owns the capture thread + pre-allocated frame
            val pipe = PipelineRunner(config, listOf(metadataStage), pub, capture, sampleRate)
            pipe.initialize()
            pipe.start()
            pipeline = pipe

            emitState("running")
            result.success(null)
        } catch (e: Exception) {
            emitState("error")
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStop(result: Result) {
        teardown()
        emitState("idle")
        result.success(null)
    }

    private fun handlePause(result: Result) {
        pipeline?.stop()
        playbackEngine?.stop()
        emitState("paused")
        result.success(null)
    }

    private fun handleResume(result: Result) {
        pipeline?.start()
        playbackEngine?.start()
        emitState("running")
        result.success(null)
    }

    private fun handleDispose(result: Result) {
        teardown()
        emitState("disposed")
        result.success(null)
    }

    private fun handleReconfigure(call: MethodCall, result: Result) {
        // Stop and restart with new config
        teardown()
        handleStart(call, result)
    }

    private fun handleFlushPlayback(result: Result) {
        playbackEngine?.flush()
        result.success(null)
    }

    private fun handleSetRoute(call: MethodCall, result: Result) {
        val routeName = call.argument<String>("route") ?: "speaker"
        val route = BoatAudioRoute.fromChannelName(routeName)
        routeManager?.setRoute(route)
        result.success(null)
    }

    private fun handleGetDiagnostics(result: Result) {
        val effects = effectsManager?.getStatus() ?: emptyMap()
        val effectMap = effects.mapValues { (_, state) ->
            mapOf("supported" to state.supported, "available" to state.available, "active" to state.active)
        }
        result.success(
            mapOf(
                "deviceModel" to android.os.Build.MODEL,
                "osVersion" to android.os.Build.VERSION.RELEASE,
                "audioSessionId" to (captureEngine?.audioSessionId ?: -1),
                "effectStatus" to effectMap,
                "currentRoute" to currentRouteName(),
                "availableRoutes" to (routeManager?.getAvailableRoutes()?.map { it.channelName } ?: listOf("speaker")),
                "captureFrameCount" to 0,
                "playbackFrameCount" to 0,
                "uptimeMs" to 0,
            )
        )
    }

    private fun teardown() {
        pipeline?.stop()
        pipeline?.dispose()
        pipeline = null
        captureEngine?.release()
        captureEngine = null
        playbackEngine?.release()
        playbackEngine = null
        effectsManager?.release()
        effectsManager = null
        routeManager?.stop()
        routeManager = null
        sessionManager?.deactivate()
        sessionManager = null
        publisher = null
    }

    private fun emitState(newState: String) {
        publisher?.emitStateChange(currentState, newState)
        currentState = newState
    }

    private fun currentRouteName(): String =
        routeManager?.currentRoute?.channelName ?: "speaker"
}
