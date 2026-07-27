import AVFoundation
import Flutter
import UIKit

final class PermissionManager {

    func check(_ type: String) -> String {
        switch type {
        case "microphone":
            return checkMicrophone()
        case "bluetoothConnect":
            // iOS handles Bluetooth audio routing via AVAudioSession; no separate permission.
            return "granted"
        default:
            return "denied"
        }
    }

    func request(_ type: String, result: @escaping FlutterResult) {
        switch type {
        case "microphone":
            requestMicrophone(result)
        case "bluetoothConnect":
            result("granted")
        default:
            result("denied")
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Microphone

    private func checkMicrophone() -> String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return "granted"
        case .denied:
            return "permanentlyDenied"
        case .undetermined:
            return "notDetermined"
        @unknown default:
            return "denied"
        }
    }

    private func requestMicrophone(_ result: @escaping FlutterResult) {
        // If already determined, return current status without showing a dialog.
        let current = AVAudioSession.sharedInstance().recordPermission
        if current == .granted {
            result("granted")
            return
        }
        if current == .denied {
            result("permanentlyDenied")
            return
        }

        let wasUndetermined = current == .undetermined

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    result(Self.mapRequestResult(granted: granted, wasUndetermined: wasUndetermined))
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    result(Self.mapRequestResult(granted: granted, wasUndetermined: wasUndetermined))
                }
            }
        }
    }

    /// If the dialog was never shown (undetermined → denied immediately),
    /// the denial is restriction-based (MDM / parental controls).
    private static func mapRequestResult(granted: Bool, wasUndetermined: Bool) -> String {
        if granted { return "granted" }
        return wasUndetermined ? "restricted" : "permanentlyDenied"
    }
}
