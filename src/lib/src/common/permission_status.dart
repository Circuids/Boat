/// Status of a runtime permission request.
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,

  /// iOS only: parental controls or MDM restriction.
  restricted,

  /// iOS only: never asked. Android maps this to [denied].
  notDetermined;

  static PermissionStatus fromString(String value) => switch (value) {
        'granted' => PermissionStatus.granted,
        'denied' => PermissionStatus.denied,
        'permanentlyDenied' => PermissionStatus.permanentlyDenied,
        'restricted' => PermissionStatus.restricted,
        'notDetermined' => PermissionStatus.notDetermined,
        _ => throw ArgumentError('Unknown PermissionStatus: $value'),
      };

  String toChannelString() => name;
}
