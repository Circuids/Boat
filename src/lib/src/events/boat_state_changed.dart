import '../common/boat_state.dart';
import 'boat_event.dart';

/// Emitted when the engine transitions between [BoatState]s.
class BoatStateChanged extends BoatEvent {
  final BoatState previous;
  final BoatState current;

  const BoatStateChanged({
    required super.timestamp,
    required this.previous,
    required this.current,
  });

  @override
  String toString() =>
      'BoatStateChanged($previous → $current at $timestamp)';
}
