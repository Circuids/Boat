import Foundation

/// Owns the ~200 ms progress timer for the media bus.
///
/// A single owner exists so the timer is always cancelled with the engine that
/// started it — no orphaned callbacks after stop/pause/deinit.
final class MediaProgressTicker {

    private let interval: TimeInterval
    private let onTick: () -> Void
    private var timer: Timer?

    init(interval: TimeInterval = 0.2, onTick: @escaping () -> Void) {
        self.interval = interval
        self.onTick = onTick
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onTick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}
