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
            pipeline?.stop()
            playbackEngine?.stop()
            emitState("paused")
            result(nil)
        case "resume":
            pipeline?.start()
            try? playbackEngine?.start()
            emitState("running")
            result(nil)
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

        emitState("starting")

        let session = AudioSessionManager()
        do {
            try session.activate(sampleRate: Double(sampleRate), bufferDurationMs: bufferMs)
        } catch {
            emitState("error")
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        sessionManager = session

        let pub = FramePublisher()
        pub.setSink(captureSink)
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
        capture.onBuffer = { [weak pipe] buffer, _ in
            pipe?.handleBuffer(buffer)
        }
        do {
            try capture.start()
        } catch {
            emitState("error")
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        captureEngine = capture

        let playback = AudioPlaybackEngine()
        try? playback.start()
        playbackEngine = playback

        emitState("running")
        result(nil)
    }

    private func handleGetDiagnostics(_ result: @escaping FlutterResult) {
        result([
            "deviceModel": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion,
            "audioSessionId": 0,
            "effectStatus": [
                "aec": ["supported": true, "available": true, "active": true],
                "agc": ["supported": true, "available": true, "active": true],
                "noiseSuppression": ["supported": true, "available": true, "active": true],
            ],
            "currentRoute": routeManager?.currentRoute.rawValue ?? "speaker",
            "availableRoutes": (routeManager?.getAvailableRoutes() ?? [.speaker]).map(\.rawValue),
            "captureFrameCount": 0,
            "playbackFrameCount": 0,
            "uptimeMs": 0,
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
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventsSink = nil
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
