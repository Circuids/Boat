import AVFoundation

/// Wraps AVAudioPlayerNode for playback via scheduleBuffer.
///
/// Uses a shared AVAudioEngine instance (provided by AudioCaptureEngine)
/// so that AEC can correlate playback and capture within a single graph.
final class AudioPlaybackEngine {
    private let engine: AVAudioEngine
    private let playerNode = AVAudioPlayerNode()
    private var isPlaying = false
    private var format: AVAudioFormat?

    init(engine: AVAudioEngine) {
        self.engine = engine
    }

    func start() throws {
        // Derive the playback format from the session's actual sample rate
        // rather than hardcoding 16kHz — the session may have negotiated a
        // different rate with the hardware.
        let sessionRate = AVAudioSession.sharedInstance().sampleRate
        let fmt = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                sampleRate: sessionRate, channels: 1, interleaved: false)
        format = fmt
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
        // Don't call engine.start() here — the capture engine already started it.
        playerNode.play()
        isPlaying = true
    }

    /// Schedules an AVAudioPCMBuffer (used by buffer-based playback).
    func schedule(buffer: AVAudioPCMBuffer) {
        guard isPlaying else { return }
        playerNode.scheduleBuffer(buffer)
    }

    /// Writes raw 16-bit LE PCM bytes to the player node.
    ///
    /// Copies exactly `frameCount * MemoryLayout<Int16>.size` bytes —
    /// not `pcm.count` — to prevent a heap overflow when the PCM data
    /// length is not an exact multiple of the frame size (odd-length PCM).
    func write(pcm: Data) {
        guard isPlaying, let fmt = format else { return }
        let frameCount = AVAudioFrameCount(pcm.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let copyBytes = Int(frameCount) * MemoryLayout<Int16>.size
        pcm.withUnsafeBytes { rawBuf in
            guard let dest = buffer.int16ChannelData?[0] else { return }
            memcpy(dest, rawBuf.baseAddress, copyBytes)
        }
        playerNode.scheduleBuffer(buffer)
    }

    func flush() {
        playerNode.stop()
        playerNode.play()
    }

    func stop() {
        isPlaying = false
        playerNode.stop()
    }
}
