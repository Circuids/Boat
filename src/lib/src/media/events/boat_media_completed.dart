import 'boat_media_event.dart';

/// Emitted when a non-looping source reaches its end.
class BoatMediaCompleted extends BoatMediaEvent {
  const BoatMediaCompleted({required super.timestamp});

  @override
  String toString() => 'BoatMediaCompleted(at $timestamp)';
}
