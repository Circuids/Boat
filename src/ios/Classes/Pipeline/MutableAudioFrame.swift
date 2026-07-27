import Foundation

/// Pre-allocated mutable frame reused across pipeline iterations.
final class MutableAudioFrame {
    var pcm: Data
    var sequenceNumber: Int64 = 0
    var timestampNanos: Int64 = 0
    var sampleRate: Int = 16000
    var channelCount: Int = 1
    var speechActive: Bool = false
    var speechConfidence: Float = 0
    var processingTimeNanos: Int64 = 0
    var dropped: Bool = false
    var validBytes: Int

    init(pcm: Data) {
        self.pcm = pcm
        self.validBytes = pcm.count
    }

    func reset() {
        sequenceNumber = 0
        timestampNanos = 0
        speechActive = false
        speechConfidence = 0
        processingTimeNanos = 0
        dropped = false
        validBytes = pcm.count
    }
}
