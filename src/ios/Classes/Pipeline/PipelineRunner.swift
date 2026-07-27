import AVFoundation
import Foundation

/// THE central object. Owns: pre-allocated frame, stage iteration,
/// deadline enforcement, error handling, and FramePublisher reference.
///
/// On iOS the AVAudioEngine tap callback IS the capture thread.
/// CapturePipeline provides the buffer handler that runs within it.
final class PipelineRunner {
    private let config: PipelineConfig
    private let stages: [PipelineStage]
    private let publisher: FramePublisher
    private let framePeriodNanos: Int64
    private let deadlineNanos: Int64
    private var consecutiveFailures = 0

    // Pre-allocated frame reused every iteration.
    private let frame: MutableAudioFrame

    private static let maxConsecutiveFailures = 50

    init(config: PipelineConfig, stages: [PipelineStage], publisher: FramePublisher,
         frameSizeBytes: Int, sampleRate: Int = 16000, channelCount: Int = 1) {
        self.config = config
        self.stages = stages
        self.publisher = publisher
        self.framePeriodNanos = Int64(config.frameDurationMs) * 1_000_000
        self.deadlineNanos = Int64(Double(framePeriodNanos) * config.deadlineFraction)
        self.frame = MutableAudioFrame(pcm: Data(count: frameSizeBytes))
        self.frame.sampleRate = sampleRate
        self.frame.channelCount = channelCount
    }

    func initialize() {
        stages.forEach { $0.initialize(config: config) }
    }

    func start() {
        stages.forEach { $0.start() }
    }

    /// Called from the AVAudioEngine tap callback (internal audio thread).
    /// Copies buffer into pre-allocated frame, then runs pipeline.
    func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size * Int(buffer.format.channelCount)
        guard byteCount > 0, let channelData = buffer.int16ChannelData else { return }

        frame.reset()
        if frame.pcm.count < byteCount {
            frame.pcm = Data(count: byteCount)
        }
        frame.pcm.withUnsafeMutableBytes { dest in
            memcpy(dest.baseAddress, channelData[0], byteCount)
        }
        frame.validBytes = byteCount

        let startNanos = DispatchTime.now().uptimeNanoseconds
        for stage in stages {
            stage.process(frame: frame)
        }

        frame.processingTimeNanos = Int64(DispatchTime.now().uptimeNanoseconds - startNanos)
        if frame.processingTimeNanos > deadlineNanos {
            publisher.emitWarning(code: "DEADLINE_EXCEEDED",
                                  message: "Frame \(frame.sequenceNumber) exceeded deadline")
        }

        publisher.publish(frame: frame)
    }

    func stop() {
        stages.forEach { $0.stop() }
    }

    func dispose() {
        stages.forEach { $0.dispose() }
    }
}
