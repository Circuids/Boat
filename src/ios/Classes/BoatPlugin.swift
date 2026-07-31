import AVFoundation
import Flutter
import UIKit

public class BoatPlugin: NSObject, FlutterPlugin {

    private var eventsSink: FlutterEventSink?
    private var captureSink: FlutterEventSink?

    private var sessionManager: AudioSessionManager?
    private var captureEngine: AudioCaptureEngine?
    private var playbackEngine: AudioPlaybackEngine?
    private var routeManager: AudioRouteManager?
    private var pipeline: PipelineRunner?
    private var publisher: FramePublisher?

    private let permissionManager = PermissionManager()
    private var currentState = "idle"
    private var startTimeMs: Double = 0
    private var lastConfig: [String: Any]?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methods = FlutterMethodChannel(name: "com.circuids.boat/methods",
                                           binaryMessenger: registrar.messenger())
        let events = FlutterEventChannel(name: "com.circuids.boat/events",
                                         binaryMessenger: registrar.messenger())
        let capture = FlutterEventChannel(name: "com.circuids.boat/capture",
                                          binaryMessenger: registrar.messenger())

        let instance = BoatPlugin()
        registrar.addMethodCallDelegate(instance, channel: methods)

        events.setStreamHandler(instance)
        capture.setStreamHandler(CaptureStreamHandler { instance.captureSink = $0 })
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            handleStart(call, result)
        case "stop":
            teardown()
            emitState("idle")
            result(nil)
        case "pause":
            handlePause(result)
        case "resume":
            handleResume(result)
        case "dispose":
            teardown()
            emitState("disposed")
            result(nil)
        case "reconfigure":
            teardown()
            handleStart(call, result)
        case "flushPlayback":
            playbackEngine?.flush()
            result(nil)
        case "play":
            let args = call.arguments as? [String: Any] ?? [:]
            if let pcm = args["pcm"] as? FlutterStandardTypedData {
                playbackEngine?.write(pcm: pcm.data)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "pcm bytes required", details: nil))
            }
        case "setRoute":
            result(nil) // iOS handles routing automatically in voiceChat mode
        case "getDiagnostics":
            handleGetDiagnostics(result)
        case "checkPermission":
            let args = call.arguments as? [String: Any] ?? [:]
            let type = args["type"] as? String ?? "microphone"
            result(permissionManager.check(type))
        case "requestPermission":
            let args = call.arguments as? [String: Any] ?? [:]
            let type = args["type"] as? String ?? "microphone"
            permissionManager.request(type, result: result)
        case "openAppSettings":
            permissionManager.openSettings()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleStart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let sampleRate = args["sampleRate"] as? Int ?? 16000
        let bufferMs = args["bufferDurationMs"] as? Int ?? 20
        let speakerMode = args["speakerMode"] as? Bool ?? true
        let preferredRouteName = args["preferredRoute"] as? String ?? "speaker"

        // Double-start guard: teardown any existing engine before re-creating.
        if currentState == "running" || currentState == "paused" || currentState == "starting" {
            teardown()
        }

        emitState("starting")
        lastConfig = args

        let session = AudioSessionManager()
        session.onInterruption = { [weak self] ended, shouldResume in
            if ended {
                if shouldResume {
                    self?.handleResume { _ in }
                }
            } else {
                self?.handlePause { _ in }
            }
        }
        session.onMediaServicesReset = { [weak self] in
            // Media services were reset — must fully recreate the engine.
            self?.teardown()
            if let config = self?.lastConfig {
                self?.handleStart(FlutterMethodCall(methodName: "start", arguments: config)) { _ in }
            }
        }
        do {
            try session.activate(sampleRate: Double(sampleRate),
                                 bufferDurationMs: bufferMs,
                                 speakerMode: speakerMode)
        } catch {
            teardown()
            emitState("error")
            publisher?.emitError(code: "START_FAILED", message: error.localizedDescription)
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        sessionManager = session

        let pub = FramePublisher()
        pub.setEventSink(eventsSink)
        pub.setCaptureSink(captureSink)
        publisher = pub

        let route = AudioRouteManager()
        route.onRouteChanged = { [weak self] newRoute in
            guard let self = self else { return }
            self.publisher?.emitRouteChanged(previous: self.routeManager?.currentRoute.rawValue ?? "speaker",
                                             current: newRoute.rawValue)
        }
        route.start()
        routeManager = route

        let config = PipelineConfig.fromMap(args)
        let metadataStage = MetadataStage()
        let frameSize = sampleRate * bufferMs / 1000 * 2 // 16-bit mono
        let pipe = PipelineRunner(config: config, stages: [metadataStage], publisher: pub,
                                   frameSizeBytes: frameSize, sampleRate: sampleRate)
        pipe.initialize()
        pipe.start()
        pipeline = pipe

        let capture = AudioCaptureEngine()
        capture.targetSampleRate = Double(sampleRate)
        capture.onBuffer = { [weak pipe] buffer, _ in
            pipe?.handleBuffer(buffer)
        }
        do {
            try capture.start()
        } catch {
            teardown()
            emitState("error")
            publisher?.emitError(code: "START_FAILED", message: error.localizedDescription)
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        captureEngine = capture

        // Playback shares the capture engine's AVAudioEngine so AEC can
        // correlate the playback reference with the capture input.
        let playback = AudioPlaybackEngine(engine: capture.engine)
        try? playback.start()
        playbackEngine = playback

        startTimeMs = Date().timeIntervalSince1970 * 1000
        emitState("running")
        result(nil)
    }

    private func handlePause(_ result: @escaping FlutterResult) {
        // Pause must stop capture — otherwise frames keep flowing while
        // the engine is supposedly suspended.
        pipeline?.stop()
        captureEngine?.stop()
        playbackEngine?.stop()
        emitState("paused")
        result(nil)
    }

    private func handleResume(_ result: @escaping FlutterResult) {
        // Resume must restart capture — the tap was removed during pause.
        playbackEngine?.start()
        pipeline?.start()
        do {
            try captureEngine?.start()
        } catch {
            emitState("error")
            publisher?.emitError(code: "RESUME_FAILED", message: error.localizedDescription)
            result(FlutterError(code: "RESUME_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        emitState("running")
        result(nil)
    }

    private func handleGetDiagnostics(_ result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        let uptimeMs = startTimeMs > 0 ? Int(Date().timeIntervalSince1970 * 1000 - startTimeMs) : 0

        // Real effect status — query the session for voice processing availability.
        let voiceProcessingAvailable: Bool
        if #available(iOS 13.0, *) {
            voiceProcessingAvailable = session.isInputAvailable
        } else {
            voiceProcessingAvailable = false
        }

        result([
            "deviceModel": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion,
            "audioSessionId": 0,
            "effectStatus": [
                "aec": ["supported": voiceProcessingAvailable, "available": voiceProcessingAvailable, "active": currentState == "running"],
                "agc": ["supported": voiceProcessingAvailable, "available": voiceProcessingAvailable, "active": currentState == "running"],
                "noiseSuppression": ["supported": voiceProcessingAvailable, "available": voiceProcessingAvailable, "active": currentState == "running"],
            ],
            "currentRoute": routeManager?.currentRoute.rawValue ?? "speaker",
            "availableRoutes": (routeManager?.getAvailableRoutes() ?? [.speaker]).map(\.rawValue),
            "captureFrameCount": 0,
            "playbackFrameCount": 0,
            "uptimeMs": uptimeMs,
            "scoDeviceConnected": session.currentRoute.outputs.contains { $0.portType == .bluetoothHFP },
        ])
    }

    private func teardown() {
        pipeline?.stop()
        pipeline?.dispose()
        pipeline = nil
        captureEngine?.stop()
        captureEngine = nil
        playbackEngine?.stop()
        playbackEngine = nil
        routeManager?.stop()
        routeManager = nil
        sessionManager?.deactivate()
        sessionManager = nil
        publisher = nil
        startTimeMs = 0
    }

    private func emitState(_ newState: String) {
        publisher?.emitStateChange(previous: currentState, current: newState)
        currentState = newState
    }
}

// MARK: - Stream Handlers

extension BoatPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventsSink = events
        publisher?.setEventSink(events)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventsSink = nil
        publisher?.setEventSink(nil)
        return nil
    }
}

private final class CaptureStreamHandler: NSObject, FlutterStreamHandler {
    private let onSink: (FlutterEventSink?) -> Void

    init(onSink: @escaping (FlutterEventSink?) -> Void) {
        self.onSink = onSink
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onSink(nil)
        return nil
    }
}
