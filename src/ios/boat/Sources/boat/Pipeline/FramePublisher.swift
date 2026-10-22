import Flutter
import Foundation

/// Serializes frames and delivers via EventChannel on the main thread.
///
/// FlutterEventSink must be called on the main thread — the capture tap
/// callback runs on an internal AVAudioEngine audio thread.
///
/// Events (state, warning, error, route) are delivered via `eventSink`
/// (the events channel). Capture data is delivered via `captureSink`
/// (the capture channel). This matches the Dart-side channel separation.
final class FramePublisher {
    private let queue = DispatchQueue(label: "com.circuids.boat.publisher")
    private var eventSink: FlutterEventSink?
    private var captureSink: FlutterEventSink?

    func setEventSink(_ sink: FlutterEventSink?) {
        queue.sync { eventSink = sink }
    }

    func setCaptureSink(_ sink: FlutterEventSink?) {
        queue.sync { captureSink = sink }
    }

    func publish(frame: MutableAudioFrame) {
        // Serialize on the publisher queue (off the audio thread), then
        // deliver on main — EventSink is main-thread-only.
        queue.async { [weak self] in
            guard let sink = self?.captureSink else { return }
            // Wire format: seq(int64) + tsNanos(int64) + sampleRate(int32) + channelCount(int32) + pcm
            var buffer = Data(capacity: 24 + frame.validBytes)
            var seq = frame.sequenceNumber.littleEndian
            var ts = frame.timestampNanos.littleEndian
            var rate = Int32(frame.sampleRate).littleEndian
            var ch = Int32(frame.channelCount).littleEndian

            withUnsafeBytes(of: &seq) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &ts) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &rate) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &ch) { buffer.append(contentsOf: $0) }
            buffer.append(frame.pcm.prefix(frame.validBytes))

            let typedData = FlutterStandardTypedData(bytes: buffer)
            DispatchQueue.main.async { sink(typedData) }
        }
    }

    func emitWarning(code: String, message: String) {
        queue.async { [weak self] in
            guard let sink = self?.eventSink else { return }
            let payload: [String: Any] = ["type": "warning", "code": code, "message": message]
            DispatchQueue.main.async { sink(payload) }
        }
    }

    func emitError(code: String, message: String) {
        queue.async { [weak self] in
            guard let sink = self?.eventSink else { return }
            let payload: [String: Any] = ["type": "error", "code": code, "message": message]
            DispatchQueue.main.async { sink(payload) }
        }
    }

    func emitStateChange(previous: String, current: String) {
        queue.async { [weak self] in
            guard let sink = self?.eventSink else { return }
            let payload: [String: Any] = ["type": "stateChanged", "previous": previous, "current": current]
            DispatchQueue.main.async { sink(payload) }
        }
    }

    func emitRouteChanged(previous: String, current: String) {
        queue.async { [weak self] in
            guard let sink = self?.eventSink else { return }
            let payload: [String: Any] = ["type": "routeChanged", "previous": previous, "current": current]
            DispatchQueue.main.async { sink(payload) }
        }
    }
}
