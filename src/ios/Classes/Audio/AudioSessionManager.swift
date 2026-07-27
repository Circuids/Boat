import AVFoundation

/// Manages AVAudioSession with .playAndRecord + .voiceChat mode.
final class AudioSessionManager {
    private let session = AVAudioSession.sharedInstance()

    func activate(sampleRate: Double, bufferDurationMs: Int) throws {
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(Double(bufferDurationMs) / 1000.0)
        try session.setActive(true)
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
