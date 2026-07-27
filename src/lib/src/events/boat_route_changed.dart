import '../common/audio_route.dart';
import 'boat_event.dart';

/// Emitted when the active audio route changes.
class BoatRouteChanged extends BoatEvent {
  final AudioRoute previous;
  final AudioRoute current;

  const BoatRouteChanged({
    required super.timestamp,
    required this.previous,
    required this.current,
  });

  @override
  String toString() =>
      'BoatRouteChanged($previous → $current at $timestamp)';
}
