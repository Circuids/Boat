import '../models/boat_media_state.dart';
import 'boat_media_event.dart';

/// Emitted when the media bus transitions between [BoatMediaState]s.
class BoatMediaStateChanged extends BoatMediaEvent {
  final BoatMediaState previous;
  final BoatMediaState current;

  const BoatMediaStateChanged({
    required super.timestamp,
    required this.previous,
    required this.current,
  });

  @override
  String toString() =>
      'BoatMediaStateChanged($previous → $current at $timestamp)';
}
