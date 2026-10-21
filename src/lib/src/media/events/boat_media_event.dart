/// Base class for all events emitted by `BoatMediaPlayer.events`.
abstract class BoatMediaEvent {
  final DateTime timestamp;

  const BoatMediaEvent({required this.timestamp});
}
