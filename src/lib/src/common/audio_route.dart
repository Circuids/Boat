/// Audio output routes supported by Boat.
enum AudioRoute {
  /// Loudspeaker — primary design target.
  speaker,

  /// Ear speaker (phone-to-ear).
  earpiece,

  /// Bluetooth SCO/A2DP.
  bluetooth,

  /// Wired headphones or headset.
  wiredHeadset,

  /// USB audio device.
  usb;

  /// Parses a route from its platform channel string representation.
  static AudioRoute fromString(String value) => switch (value) {
        'speaker' => AudioRoute.speaker,
        'earpiece' => AudioRoute.earpiece,
        'bluetooth' => AudioRoute.bluetooth,
        'wiredHeadset' => AudioRoute.wiredHeadset,
        'usb' => AudioRoute.usb,
        _ => throw ArgumentError('Unknown AudioRoute: $value'),
      };

  /// Returns the platform channel string representation.
  String toChannelString() => name;
}
