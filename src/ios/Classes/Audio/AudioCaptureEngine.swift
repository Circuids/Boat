import AVFoundation

/// Thin wrapper around a shared AVAudioEngine: tap installation, lifecycle.
/// The tap callback IS the capture thread on iOS — PipelineRunner provides
/// the frame handler that runs within it.
///
/// The engine instance is shared with AudioPlaybackEngine so that AEC
/// can correlate the playback reference signal with the capture input
/// within a single AVAudioEngine graph.
///
/// Captures at the hardware sample rate and resamples to the target rate
/// (typically 16kHz) via AVAudioConverter — the input node's native format
/// is usually 48kHz and the pipeline expects 16kHz.
final class AudioCaptureEngine {
    let engine = AVAudioEngine()

    // Thread-safe capture flag — the audio thread reads it, the main
    // thread writes it. Protected by an os_unfair_lock.
    private var _isCapturing = false
    private let isCapturingLock = os_unfair_lock()

    private var isCapturing: Bool {
        get {
            os_unfair_lock_lock(&isCapturingLock)
            let value = _isCapturing
            os_unfair_lock_unlock(&isCapturingLock)
            return value
        }
        set {
            os_unfair_lock_lock(&isCapturingLock)
            _isCapturing = newValue
            os_unfair_lock_unlock(&isCapturingLock)
        }
    }

    /// Called on the internal audio thread for each captured buffer.
    /// The buffer is resampled to the target format before delivery.
    var onBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    private var targetFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var configChangeObserver: NSObjectProtocol?

    /// Target sample rate for the resampled output (default 16kHz).
    var targetSampleRate: Double = 16000

    func start() throws {
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        let targetFmt = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: targetSampleRate,
                                       channels: 1, interleaved: false)
        targetFormat = targetFmt
        converter = AVAudioConverter(from: hardwareFormat, to: targetFmt)

        // Observe configuration changes (route changes) so we can
        // reinstall the tap with the new format.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }

        installTap(format: hardwareFormat)

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    private func installTap(format: AVAudioFormat) {
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isCapturing else { return }
            self.processAndDeliver(buffer: buffer, time: time)
        }
    }

    /// Resamples the captured buffer from hardware format to target format,
    /// then delivers it to the onBuffer callback.
    private func processAndDeliver(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let converter = converter, let targetFmt = targetFormat else {
            onBuffer?(buffer, time)
            return
        }

        // Estimate output frame count from the input frame count and
        // sample rate ratio. The converter may produce slightly fewer.
        let ratio = targetFmt.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: outputFrameCapacity) else {
            return
        }

        var error: NSError?
        var converted = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converted = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if converted && outputBuffer.frameLength > 0 {
            onBuffer?(outputBuffer, time)
        }
    }

    /// Called when the AVAudioEngine configuration changes (e.g. headphone
    /// unplug). Reinstalls the tap with the new hardware format.
    private func handleConfigurationChange() {
        guard isCapturing else { return }
        let inputNode = engine.inputNode
        let newFormat = inputNode.outputFormat(forBus: 0)
        let targetFmt = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: targetSampleRate,
                                       channels: 1, interleaved: false)
        converter = AVAudioConverter(from: newFormat, to: targetFmt)
        targetFormat = targetFmt

        // Reinstall tap with the new format. The engine should be
        // restarted after a configuration change.
        if engine.isRunning {
            installTap(format: newFormat)
        }
    }

    func stop() {
        // Guard against double-stop — removeTap crashes if no tap is installed.
        guard isCapturing else { return }
        isCapturing = false
        if let obs = configChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            configChangeObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
