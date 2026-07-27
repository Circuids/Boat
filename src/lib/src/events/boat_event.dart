/// Base class for all events emitted by [BoatEngine.events].
abstract class BoatEvent {
  final DateTime timestamp;

  const BoatEvent({required this.timestamp});
}
