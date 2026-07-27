import '../exceptions/boat_exception.dart';
import 'boat_event.dart';

/// Fatal error that moved the engine to [BoatState.error].
class BoatError extends BoatEvent {
  final BoatException exception;

  const BoatError({
    required super.timestamp,
    required this.exception,
  });

  @override
  String toString() => 'BoatError(${exception.message})';
}
