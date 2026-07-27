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
    var currentRoute: BoatAudioRoute = .speaker
    var onRouteChanged: ((BoatAudioRoute) -> Void)?

    func start() {
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
    }

    func getAvailableRoutes() -> [BoatAudioRoute] {
        var routes: [BoatAudioRoute] = [.speaker, .earpiece]
        let session = AVAudioSession.sharedInstance()
        for output in session.currentRoute.outputs {
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                routes.append(.bluetooth)
            case .headphones, .headsetMic:
                routes.append(.wiredHeadset)
            case .usbAudio, .usbHeadset:
                routes.append(.usb)
            default:
                break
            }
        }
        return Array(Set(routes))
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
