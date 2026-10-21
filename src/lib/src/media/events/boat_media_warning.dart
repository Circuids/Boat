import 'boat_media_event.dart';

/// Non-fatal condition on the media bus (e.g. audio focus loss, truncated WAV).
class BoatMediaWarning extends BoatMediaEvent {
  final String code;
  final String message;

  const BoatMediaWarning({
    required super.timestamp,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'BoatMediaWarning($code: $message)';
}
