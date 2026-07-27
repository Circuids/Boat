import Foundation

/// Frame identity: sequence number, timestamp.
final class MetadataStage: PipelineStage {
    private var sequenceCounter: Int64 = 0
    private var startNanos: UInt64 = 0

    func initialize(config: PipelineConfig) {
        sequenceCounter = 0
        startNanos = DispatchTime.now().uptimeNanoseconds
    }

    func process(frame: MutableAudioFrame) {
        frame.sequenceNumber = sequenceCounter
        sequenceCounter += 1
        frame.timestampNanos = Int64(DispatchTime.now().uptimeNanoseconds - startNanos)
    }

    func start() {}
    func stop() {}
    func dispose() {}
}
