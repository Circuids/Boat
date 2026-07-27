/// Status of a single OS audio effect.
class EffectStatus {
  /// Device hardware supports this effect type.
  final bool supported;

  /// Effect is currently available for use.
  final bool available;

  /// Effect is actively processing audio.
  final bool active;

  const EffectStatus({
    required this.supported,
    required this.available,
    required this.active,
  });

  @override
  String toString() =>
      'EffectStatus(supported: $supported, available: $available, active: $active)';
}
