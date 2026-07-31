import AVFoundation

enum BoatAudioRoute: String, CaseIterable {
    case speaker
    case earpiece
    case bluetooth
    case wiredHeadset
    case usb
}

/// Observes AVAudioSession.routeChangeNotification.
/// iOS handles routing automatically in voiceChat mode.
final class AudioRouteManager {
    private var observer: NSObjectProtocol?
    private var started = false
    var currentRoute: BoatAudioRoute = .speaker
    var onRouteChanged: ((BoatAudioRoute) -> Void)?

    func start() {
        // Guard against double-call — would leak the observer.
        guard !started else { return }
        started = true
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRouteChange()
        }
        currentRoute = detectCurrentRoute()
    }

    func stop() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        started = false
    }

    /// Returns available routes preserving insertion order (no Set —
    /// Set loses order and can produce non-deterministic route lists).
    func getAvailableRoutes() -> [BoatAudioRoute] {
        var routes: [BoatAudioRoute] = [.speaker, .earpiece]
        let session = AVAudioSession.sharedInstance()
        for output in session.currentRoute.outputs {
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                if !routes.contains(.bluetooth) { routes.append(.bluetooth) }
            case .headphones, .headsetMic:
                if !routes.contains(.wiredHeadset) { routes.append(.wiredHeadset) }
            case .usbAudio, .usbHeadset:
                if !routes.contains(.usb) { routes.append(.usb) }
            default:
                break
            }
        }
        return routes
    }

    private func handleRouteChange() {
        let newRoute = detectCurrentRoute()
        if newRoute != currentRoute {
            currentRoute = newRoute
            onRouteChanged?(newRoute)
        }
    }

    private func detectCurrentRoute() -> BoatAudioRoute {
        let session = AVAudioSession.sharedInstance()
        for output in session.currentRoute.outputs {
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                return .bluetooth
            case .headphones, .headsetMic:
                return .wiredHeadset
            case .usbAudio, .usbHeadset:
                return .usb
            case .builtInReceiver:
                return .earpiece
            default:
                continue
            }
        }
        return .speaker
    }
}
