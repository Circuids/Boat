import AVFoundation
import Flutter
import UIKit

/// Media bus plugin: wires `com.circuids.boat/media` and
/// `com.circuids.boat/mediaEvents`.
///
/// Disjoint from the voice plugin's channels. The only shared state is
/// `MediaSessionArbiter`, which the voice plugin also acquires.
final class BoatMediaPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventsSink: FlutterEventSink?
    private var engine: MediaPlaybackEngine?
    private var ticker: MediaProgressTicker?
    private weak var registrar: FlutterPluginRegistrar?

    private var state = "idle"
    private var sourceKind = "none"
    private var loop = false
    private var pcmFormat: (sampleRate: Double, channels: UInt32)?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BoatMediaPlugin()
        let methods = FlutterMethodChannel(
            name: "com.circuids.boat/media",
            binaryMessenger: registrar.messenger()
        )
        let events = FlutterEventChannel(
            name: "com.circuids.boat/mediaEvents",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methods)
        events.setStreamHandler(instance)
        instance.registrar = registrar
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventsSink = events
        MediaSessionArbiter.shared.onMediaStop = { [weak self] in
            self?.stopInternal(emitPreempted: true)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventsSink = nil
        return nil
    }

    // MARK: - Method dispatch

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "mediaStart":
            handleStart(args, result)
        case "mediaStop":
            stopInternal(emitPreempted: false)
            result(nil)
        case "mediaPlayPcm":
            handlePlayPcm(args, result)
        case "mediaPlayFile":
            handlePlayFile(args, result)
        case "mediaPlayAsset":
            handlePlayAsset(args, result)
        case "mediaPause":
            handlePause(result)
        case "mediaResume":
            handleResume(result)
        case "mediaSeek":
            handleSeek(args, result)
        case "mediaSetVolume":
            engine?.setVolume(Float((args["volume"] as? Double) ?? 1.0))
            result(nil)
        case "mediaFlush":
            engine?.flush()
            result(nil)
        case "mediaGetStatus":
            result(statusMap())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Handlers

    private func handleStart(_ args: [String: Any], _ result: @escaping FlutterResult) {
        if state != "idle" && state != "error" {
            result(nil) // idempotent while already started
            return
        }
        guard MediaSessionArbiter.shared.acquireMedia() else {
            result(FlutterError(code: "MEDIA_BUSY",
                                message: "Voice engine owns the audio session",
                                details: nil))
            return
        }
        let sampleRate = Double((args["sampleRate"] as? Int) ?? 48000)
        let channels = UInt32((args["channelCount"] as? Int) ?? 2)
        let bits = (args["bitsPerSample"] as? Int) ?? 16
        guard bits == 16 else {
            MediaSessionArbiter.shared.release(.media)
            result(FlutterError(code: "MEDIA_FORMAT_MISMATCH",
                                message: "Only 16-bit PCM is supported",
                                details: nil))
            return
        }
        do {
            let eng = MediaPlaybackEngine()
            try eng.activateSession(sampleRate: sampleRate)
            try eng.configure(sampleRate: sampleRate, channelCount: channels)
            eng.onCompleted = { [weak self] in self?.handleCompleted() }
            engine = eng
            pcmFormat = (sampleRate, channels)
            ticker = MediaProgressTicker { [weak self] in self?.emitProgress() }
            setState("loading")
            result(nil)
        } catch {
            MediaSessionArbiter.shared.release(.media)
            setState("error")
            result(FlutterError(code: "MEDIA_START_FAILED",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    private func handlePlayPcm(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let typed = args["pcm"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "MEDIA_FORMAT_MISMATCH",
                                message: "pcm bytes required",
                                details: nil))
            return
        }
        guard let fmt = pcmFormat, let eng = engine else {
            result(FlutterError(code: "MEDIA_INVALID_STATE",
                                message: "mediaStart must be called first",
                                details: nil))
            return
        }
        let bytesPerFrame = Int(fmt.channels) * 2
        if typed.data.isEmpty || typed.data.count % bytesPerFrame != 0 {
            result(FlutterError(code: "MEDIA_FORMAT_MISMATCH",
                                message: "PCM length \(typed.data.count) is not a multiple of frame size \(bytesPerFrame)",
                                details: nil))
            return
        }
        sourceKind = "pcm"
        eng.write(pcm: typed.data)
        ticker?.start()
        setState("playing")
        result(nil)
    }

    private func handlePlayFile(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let path = args["path"] as? String else {
            result(FlutterError(code: "MEDIA_SOURCE_FAILED", message: "path required", details: nil))
            return
        }
        playWav(path: path, loop: (args["loop"] as? Bool) ?? false, kind: "file", result: result)
    }

    private func handlePlayAsset(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let key = args["assetKey"] as? String else {
            result(FlutterError(code: "MEDIA_SOURCE_FAILED", message: "assetKey required", details: nil))
            return
        }
        guard let registrar = registrar else {
            result(FlutterError(code: "MEDIA_SOURCE_FAILED", message: "registrar unavailable", details: nil))
            return
        }
        let lookup = registrar.lookupKey(forAsset: key)
        guard let path = Bundle.main.path(forResource: lookup, ofType: nil) else {
            result(FlutterError(code: "MEDIA_SOURCE_FAILED",
                                message: "Asset not found: \(key)",
                                details: nil))
            return
        }
        playWav(path: path, loop: (args["loop"] as? Bool) ?? false, kind: "asset", result: result)
    }

    private func playWav(path: String, loop: Bool, kind: String, result: @escaping FlutterResult) {
        guard state != "idle" && state != "error" else {
            result(FlutterError(code: "MEDIA_INVALID_STATE",
                                message: "mediaStart must be called first",
                                details: nil))
            return
        }
        guard let eng = engine else {
            result(FlutterError(code: "MEDIA_INVALID_STATE",
                                message: "mediaStart must be called first",
                                details: nil))
            return
        }
        do {
            self.loop = loop
            sourceKind = kind
            try eng.openFile(path: path)
            ticker?.start()
            setState("playing")
            result(nil)
        } catch {
            setState("error")
            emit(["type": "mediaError",
                  "code": "MEDIA_SOURCE_FAILED",
                  "message": error.localizedDescription])
            result(FlutterError(code: "MEDIA_SOURCE_FAILED",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    private func handlePause(_ result: @escaping FlutterResult) {
        guard state == "playing" else {
            result(FlutterError(code: "MEDIA_INVALID_STATE",
                                message: "pause requires playing, was \(state)",
                                details: nil))
            return
        }
        ticker?.stop()
        engine?.pause()
        setState("paused")
        result(nil)
    }

    private func handleResume(_ result: @escaping FlutterResult) {
        guard state == "paused" else {
            result(FlutterError(code: "MEDIA_INVALID_STATE",
                                message: "resume requires paused, was \(state)",
                                details: nil))
            return
        }
        engine?.resume()
        ticker?.start()
        setState("playing")
        result(nil)
    }

    private func handleSeek(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard sourceKind == "file" || sourceKind == "asset" else {
            result(FlutterError(code: "MEDIA_INVALID_STATE",
                                message: "seek requires a file or asset source",
                                details: nil))
            return
        }
        engine?.seek(toMilliseconds: (args["positionMs"] as? Int) ?? 0)
        result(nil)
    }

    private func handleCompleted() {
        guard state == "playing" else { return }
        if loop {
            engine?.scheduleFromCurrentPosition()
            return
        }
        ticker?.stop()
        setState("completed")
        emit(["type": "mediaCompleted"])
    }

    // MARK: - Teardown

    private func stopInternal(emitPreempted: Bool) {
        ticker?.stop()
        ticker = nil
        engine?.release()
        engine = nil
        pcmFormat = nil
        sourceKind = "none"
        loop = false
        MediaSessionArbiter.shared.release(.media)
        setState("idle")
        if emitPreempted {
            emit(["type": "mediaPreempted", "reason": "voiceEngineStarted"])
        }
    }

    // MARK: - Events

    private func setState(_ next: String) {
        guard state != next else { return }
        let previous = state
        state = next
        emit(["type": "mediaStateChanged", "previous": previous, "current": next])
    }

    private func emitProgress() {
        guard state == "playing", let eng = engine else { return }
        emit(["type": "mediaProgress",
              "positionMs": eng.positionMilliseconds,
              "durationMs": eng.durationMilliseconds])
    }

    private func emit(_ payload: [String: Any]) {
        guard let sink = eventsSink else { return }
        DispatchQueue.main.async { sink(payload) }
    }

    private func statusMap() -> [String: Any] {
        [
            "state": state,
            "positionMs": engine?.positionMilliseconds ?? 0,
            "durationMs": engine?.durationMilliseconds ?? -1,
            "volume": Double(engine?.volume ?? 1.0),
            "sourceKind": sourceKind,
            "loop": loop,
        ]
    }
}
