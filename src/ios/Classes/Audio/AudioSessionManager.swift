import AVFoundation

/// Manages AVAudioSession with .playAndRecord + .voiceChat mode.
///
/// Speaker mode is enforced via the .defaultToSpeaker option when
/// speakerMode is true (the primary design target for Boat).
///
/// Handles AVAudioSession interruptions (phone calls, Siri) and
/// media-services-reset notifications so the engine can pause/resume
/// or fully recreate itself as needed.
final class AudioSessionManager {
    private let session = AVAudioSession.sharedInstance()
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?

    /// Called when an interruption begins (`.began`) or ends (`.ended`).
    /// On `.ended` with `.shouldResume`, the engine should resume.
    var onInterruption: ((Bool, Bool) -> Void)?

    /// Called when media services are reset — the engine must be fully
    /// torn down and recreated.
    var onMediaServicesReset: (() -> Void)?

    func activate(sampleRate: Double, bufferDurationMs: Int, speakerMode: Bool = true) throws {
        var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
        if speakerMode {
            options.insert(.defaultToSpeaker)
        }
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(Double(bufferDurationMs) / 1000.0)
        try session.setActive(true)
        registerNotifications()
    }

    func deactivate() {
        unregisterNotifications()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Notifications

    private func registerNotifications() {
        unregisterNotifications()

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onMediaServicesReset?()
        }
    }

    private func unregisterNotifications() {
        if let obs = interruptionObserver {
            NotificationCenter.default.removeObserver(obs)
            interruptionObserver = nil
        }
        if let obs = mediaResetObserver {
            NotificationCenter.default.removeObserver(obs)
            mediaResetObserver = nil
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            onInterruption?(false, false)
        case .ended:
            let shouldResume: Bool
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            } else {
                shouldResume = false
            }
            onInterruption?(true, shouldResume)
        @unknown default:
            break
        }
    }
}
