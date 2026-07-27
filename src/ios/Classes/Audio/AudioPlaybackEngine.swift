import AVFoundation

/// Wraps AVAudioPlayerNode for playback via scheduleBuffer.
final class AudioPlaybackEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlaying = false

    func start() throws {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        engine.prepare()
        try engine.start()
        playerNode.play()
        isPlaying = true
    }

    func schedule(buffer: AVAudioPCMBuffer) {
        guard isPlaying else { return }
        playerNode.scheduleBuffer(buffer)
    }

    func flush() {
        playerNode.stop()
        playerNode.play()
    }

    func stop() {
        isPlaying = false
        playerNode.stop()
        engine.stop()
    }
}
