import Flutter
import Foundation

/// Serializes frames and delivers via EventChannel on a serial queue.
final class FramePublisher {
    private let queue = DispatchQueue(label: "com.circuids.boat.publisher")
    private var eventSink: FlutterEventSink?

    func setSink(_ sink: FlutterEventSink?) {
        queue.sync { eventSink = sink }
    }

    func publish(frame: MutableAudioFrame) {
        queue.async { [weak self] in
            guard let sink = self?.eventSink else { return }
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

            sink(FlutterStandardTypedData(bytes: buffer))
        }
    }

    func emitWarning(code: String, message: String) {
        queue.async { [weak self] in
            self?.eventSink?(["type": "warning", "code": code, "message": message])
        }
    }

    func emitStateChange(previous: String, current: String) {
        queue.async { [weak self] in
            self?.eventSink?(["type": "stateChanged", "previous": previous, "current": current])
        }
    }

    func emitRouteChanged(previous: String, current: String) {
        queue.async { [weak self] in
            self?.eventSink?(["type": "routeChanged", "previous": previous, "current": current])
        }
    }
}
