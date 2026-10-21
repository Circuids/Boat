import 'boat_media_event.dart';

/// Periodic playback position update, emitted roughly every 200 ms while
/// playing.
class BoatMediaProgress extends BoatMediaEvent {
  final Duration position;

  /// Total duration, or `null` when unknown (streaming PCM).
  final Duration? duration;

  const BoatMediaProgress({
    required super.timestamp,
    required this.position,
    required this.duration,
  });

  @override
  String toString() => 'BoatMediaProgress($position / $duration)';
}
