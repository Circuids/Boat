import 'boat_media_event.dart';

/// Emitted when the voice engine took the audio session from the media bus.
///
/// The media bus transitions to `idle`. This is the only channel through which
/// Dart learns about preemption — the native arbiter owns that decision.
class BoatMediaPreempted extends BoatMediaEvent {
  /// Why the session was taken. Currently always `voiceEngineStarted`.
  final String reason;

  const BoatMediaPreempted({required super.timestamp, required this.reason});

  @override
  String toString() => 'BoatMediaPreempted($reason)';
}
