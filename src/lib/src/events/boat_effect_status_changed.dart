import '../common/audio_effect_type.dart';
import 'boat_event.dart';

/// Emitted when an audio effect's availability or active state changes.
class BoatEffectStatusChanged extends BoatEvent {
  final AudioEffectType effect;
  final bool available;
  final bool active;

  const BoatEffectStatusChanged({
    required super.timestamp,
    required this.effect,
    required this.available,
    required this.active,
  });

  @override
  String toString() =>
      'BoatEffectStatusChanged($effect: available=$available, active=$active)';
}
