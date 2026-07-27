/// Permissions managed by Boat.
enum PermissionType {
  /// RECORD_AUDIO (Android) / microphone usage (iOS).
  microphone,

  /// BLUETOOTH_CONNECT (Android 12+). Returns [PermissionStatus.granted] on iOS.
  bluetoothConnect;

  static PermissionType fromString(String value) => switch (value) {
        'microphone' => PermissionType.microphone,
        'bluetoothConnect' => PermissionType.bluetoothConnect,
        _ => throw ArgumentError('Unknown PermissionType: $value'),
      };

  String toChannelString() => name;
}
