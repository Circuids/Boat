import AVFoundation

/// Thin wrapper around AVAudioEngine: creation, tap installation, lifecycle.
/// The tap callback IS the capture thread on iOS — CapturePipeline provides
/// the frame handler that runs within it.
final class AudioCaptureEngine {
    private let engine = AVAudioEngine()
    private var isCapturing = false

    /// Called on the internal audio thread for each captured buffer.
    var onBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    func start() throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isCapturing else { return }
            self.onBuffer?(buffer, time)
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    func stop() {
        isCapturing = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
