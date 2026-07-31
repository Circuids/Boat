import AVFoundation
import Foundation

/// THE central object. Owns: pre-allocated frame, stage iteration,
/// deadline enforcement, error handling, and FramePublisher reference.
///
/// On iOS the AVAudioEngine tap callback IS the capture thread.
/// CapturePipeline provides the buffer handler that runs within it.
///
/// Uses double-buffering to eliminate the data race between the audio
/// thread (writes to the active frame) and the publisher queue (reads
/// from the inactive frame to serialize it).
final class PipelineRunner {
    private let config: PipelineConfig
    private let stages: [PipelineStage]
    private let publisher: FramePublisher
    private let framePeriodNanos: Int64
    private let deadlineNanos: Int64

    // Per-stage disabled flags — once a stage exceeds maxConsecutiveFailures
    // it is skipped for subsequent frames.
    private var stageDisabled: [Bool]
    private var stageFailures: [Int]

    // Double-buffer: the audio thread writes to the active frame while
    // the publisher queue reads from the inactive frame. They swap on
    // each publish so neither thread touches the same buffer simultaneously.
    private let frameA: MutableAudioFrame
    private let frameB: MutableAudioFrame
    private var activeFrame: MutableAudioFrame

    private static let maxConsecutiveFailures = 50

    init(config: PipelineConfig, stages: [PipelineStage], publisher: FramePublisher,
         frameSizeBytes: Int, sampleRate: Int = 16000, channelCount: Int = 1) {
        self.config = config
        self.stages = stages
        self.publisher = publisher
        self.framePeriodNanos = Int64(config.frameDurationMs) * 1_000_000
        self.deadlineNanos = Int64(Double(framePeriodNanos) * config.deadlineFraction)
        self.frameA = MutableAudioFrame(pcm: Data(count: frameSizeBytes))
        self.frameB = MutableAudioFrame(pcm: Data(count: frameSizeBytes))
        self.activeFrame = frameA
        self.stageDisabled = Array(repeating: false, count: stages.count)
        self.stageFailures = Array(repeating: 0, count: stages.count)
        self.frameA.sampleRate = sampleRate
        self.frameA.channelCount = channelCount
        self.frameB.sampleRate = sampleRate
        self.frameB.channelCount = channelCount
    }

    func initialize() {
        stages.forEach { $0.initialize(config: config) }
    }

    func start() {
        stages.forEach { $0.start() }
    }

    /// Called from the AVAudioEngine tap callback (internal audio thread).
    /// Copies buffer into the active frame, runs pipeline, then swaps
    /// buffers and publishes the previously-active frame.
    func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size * Int(buffer.format.channelCount)
        guard byteCount > 0, let channelData = buffer.int16ChannelData else { return }

        let frame = activeFrame
        frame.reset()
        if frame.pcm.count < byteCount {
            frame.pcm = Data(count: byteCount)
        }
        frame.pcm.withUnsafeMutableBytes { dest in
            memcpy(dest.baseAddress, channelData[0], byteCount)
        }
        frame.validBytes = byteCount

        let startNanos = DispatchTime.now().uptimeNanoseconds
        for (index, stage) in stages.enumerated() {
            if stageDisabled[index] { continue }
            do {
                stage.process(frame: frame)
                stageFailures[index] = 0
            } catch {
                stageFailures[index] += 1
                if stageFailures[index] >= Self.maxConsecutiveFailures && !stageDisabled[index] {
                    stageDisabled[index] = true
                    publisher.emitWarning(
                        code: "STAGE_DISABLED",
                        message: "Stage disabled after \(Self.maxConsecutiveFailures) consecutive failures"
                    )
                }
            }
        }

        frame.processingTimeNanos = Int64(DispatchTime.now().uptimeNanoseconds - startNanos)
        if frame.processingTimeNanos > deadlineNanos {
            publisher.emitWarning(code: "DEADLINE_EXCEEDED",
                                  message: "Frame \(frame.sequenceNumber) exceeded deadline")
        }

        // Swap buffers: the frame we just wrote becomes the publish
        // target, and the other frame becomes the active frame for the
        // next callback. The publisher queue reads the publish frame
        // while the audio thread writes to the new active frame.
        let publishFrame = frame
        activeFrame = (frame === frameA) ? frameB : frameA
        publisher.publish(frame: publishFrame)
    }

    func stop() {
        stages.forEach { $0.stop() }
    }

    func dispose() {
        stages.forEach { $0.dispose() }
    }
}
