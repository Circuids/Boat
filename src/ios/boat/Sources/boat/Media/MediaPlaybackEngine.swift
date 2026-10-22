import AVFoundation

/// Media output: its own AVAudioEngine under the `.playback` category.
///
/// Deliberately never reuses the capture engine's graph — that graph is the
/// voice processing graph, and attaching media to it would re-couple the buses
/// and force `.playAndRecord`/`.voiceChat`.
final class MediaPlaybackEngine {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var format: AVAudioFormat?
    private var audioFile: AVAudioFile?
    private var scheduledBuffers = 0
    private var isPlaying = false

    /// Called on the main queue when a non-looping source finishes.
    var onCompleted: (() -> Void)?

    private(set) var sampleRate: Double = 48000
    private(set) var channelCount: UInt32 = 2
    private(set) var volume: Float = 1.0

    // MARK: - Session

    /// Activates the media session. `.playback` only — never `.playAndRecord`.
    func activateSession(sampleRate: Double) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(0.020)
        try session.setActive(true)
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Graph

    /// Configures the graph for the given source format.
    func configure(sampleRate: Double, channelCount: UInt32) throws {
        teardownGraph()

        self.sampleRate = sampleRate
        self.channelCount = channelCount

        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw MediaError.format("Cannot build AVAudioFormat for \(sampleRate)Hz/\(channelCount)ch")
        }
        format = fmt

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
        engine.prepare()
        try engine.start()
        playerNode.volume = volume
        playerNode.play()
        isPlaying = true
    }

    // MARK: - Sources

    /// Opens a WAV file and schedules it from the current frame position.
    func openFile(path: String) throws {
        let url = URL(fileURLWithPath: path)
        let file = try AVAudioFile(forReading: url)
        audioFile = file
        try configure(
            sampleRate: file.processingFormat.sampleRate,
            channelCount: file.processingFormat.channelCount
        )
        scheduleFromCurrentPosition()
    }

    /// Schedules the whole file from its current `framePosition`.
    func scheduleFromCurrentPosition() {
        guard let file = audioFile, let fmt = format else { return }
        file.framePosition = 0
        scheduleRemaining(file: file, format: fmt)
    }

    private func scheduleRemaining(file: AVAudioFile, format: AVAudioFormat) {
        let remaining = AVAudioFrameCount(file.length - file.framePosition)
        guard remaining > 0 else {
            notifyCompleted()
            return
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: remaining) else {
            return
        }
        do {
            try file.read(into: buffer)
        } catch {
            return
        }
        scheduledBuffers += 1
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self = self else { return }
            self.scheduledBuffers -= 1
            if self.scheduledBuffers == 0 {
                self.notifyCompleted()
            }
        }
    }

    /// Writes raw 16-bit LE PCM bytes to the player node.
    ///
    /// Copies exactly `frameCount * 2` bytes — not `pcm.count` — so odd-length
    /// PCM cannot overrun the destination buffer.
    func write(pcm: Data) {
        guard isPlaying, let fmt = format else { return }
        let frameCount = AVAudioFrameCount(pcm.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else {
            return
        }
        buffer.frameLength = frameCount
        let copyBytes = Int(frameCount) * MemoryLayout<Int16>.size
        pcm.withUnsafeBytes { raw in
            guard let dest = buffer.int16ChannelData?[0], let src = raw.baseAddress else { return }
            memcpy(dest, src, copyBytes)
        }
        scheduledBuffers += 1
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self = self else { return }
            self.scheduledBuffers -= 1
            if self.scheduledBuffers == 0 {
                self.notifyCompleted()
            }
        }
    }

    // MARK: - Transport

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func resume() {
        playerNode.play()
        isPlaying = true
    }

    func seek(toMilliseconds ms: Int) {
        guard let file = audioFile else { return }
        let frames = AVAudioFramePosition(Double(ms) / 1000.0 * file.processingFormat.sampleRate)
        playerNode.stop()
        file.framePosition = min(max(frames, 0), file.length)
        scheduledBuffers = 0
        playerNode.play()
        isPlaying = true
        scheduleRemaining(file: file, format: file.processingFormat)
    }

    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
        playerNode.volume = volume
    }

    func flush() {
        playerNode.stop()
        scheduledBuffers = 0
        if isPlaying { playerNode.play() }
    }

    /// Current position in milliseconds, derived from the file's frame position.
    var positionMilliseconds: Int {
        guard let file = audioFile else { return 0 }
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return 0 }
        return Int(Double(file.framePosition) / rate * 1000.0)
    }

    var durationMilliseconds: Int {
        guard let file = audioFile else { return -1 }
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return -1 }
        return Int(Double(file.length) / rate * 1000.0)
    }

    func teardownGraph() {
        playerNode.stop()
        engine.stop()
        if engine.attachedNodes.contains(playerNode) {
            engine.detach(playerNode)
        }
        audioFile = nil
        scheduledBuffers = 0
        isPlaying = false
    }

    func release() {
        teardownGraph()
        deactivateSession()
    }

    private func notifyCompleted() {
        DispatchQueue.main.async { [weak self] in
            self?.onCompleted?()
        }
    }

    enum MediaError: Error, LocalizedError {
        case format(String)

        var errorDescription: String? {
            switch self {
            case .format(let message): return message
            }
        }
    }
}
