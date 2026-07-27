import '../../boat_platform_interface.dart';
import '../common/common.dart';

/// Zero-dependency runtime permission utility for Boat.
///
/// Call [request] before [BoatEngine.start] to show the OS permission dialog.
/// [BoatEngine.start] performs a check-only gate and throws
/// [BoatPermissionException] if the microphone permission is not granted.
class BoatPermission {
  BoatPermission._();

  /// Checks the current status of [type] without showing any dialog.
  static Future<PermissionStatus> check(PermissionType type) =>
      BoatPlatform.instance.checkPermission(type);

  /// Requests [type] from the user. Shows the OS dialog if needed.
  static Future<PermissionStatus> request(PermissionType type) =>
      BoatPlatform.instance.requestPermission(type);

  /// Opens the app's system settings page.
  static Future<void> openSettings() =>
      BoatPlatform.instance.openAppSettings();
}
