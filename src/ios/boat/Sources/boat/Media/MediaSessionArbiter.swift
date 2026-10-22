import Foundation

/// Process-wide owner of the OS audio session.
///
/// The session is a singleton OS resource, so exactly one bus may own it at a
/// time. Voice always wins: `acquireVoice()` preempts media, while
/// `acquireMedia()` refuses when voice holds it. Media never preempts voice — a
/// UI cue must never interrupt a conversation.
///
/// Holds no audio resources, only the ownership enum and the media-stop
/// callback.
final class MediaSessionArbiter {

    enum Owner {
        case none
        case voice
        case media
    }

    static let shared = MediaSessionArbiter()

    private let lock = NSLock()
    private var _owner: Owner = .none

    /// Invoked synchronously by `acquireVoice()` when media currently owns the
    /// session. Must stop media playback and return only once the output has
    /// stopped writing, so voice never starts while media is still draining.
    var onMediaStop: (() -> Void)?

    private init() {}

    var owner: Owner {
        lock.lock()
        defer { lock.unlock() }
        return _owner
    }

    /// Acquires the session for voice. Always succeeds; preempts media first.
    func acquireVoice() {
        lock.lock()
        let preempt = _owner == .media
        _owner = .voice
        lock.unlock()

        // Invoke outside the lock: the callback tears down the media engine,
        // which must not re-enter the arbiter while we hold it.
        if preempt {
            onMediaStop?()
        }
    }

    /// Acquires the session for media.
    ///
    /// - Returns: `false` when voice owns the session — the caller must surface
    ///   `MEDIA_BUSY` rather than proceeding.
    func acquireMedia() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _owner == .voice { return false }
        _owner = .media
        return true
    }

    /// Releases the session if `expected` is the current owner.
    func release(_ expected: Owner) {
        lock.lock()
        defer { lock.unlock() }
        if _owner == expected { _owner = .none }
    }

    /// Test-only reset.
    func resetForTest() {
        lock.lock()
        defer { lock.unlock() }
        _owner = .none
        onMediaStop = nil
    }
}
