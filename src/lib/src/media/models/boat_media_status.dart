import 'boat_media_state.dart';

/// Kind of source currently loaded on the media bus.
enum BoatMediaSourceKind {
  /// No source loaded.
  none,

  /// Streaming PCM supplied by the consumer.
  pcm,

  /// WAV file on disk.
  file,

  /// WAV asset bundled with the app.
  asset;

  /// Parses a channel string, falling back to [none] for unknown values.
  static BoatMediaSourceKind fromString(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return none;
  }
}

/// Snapshot of media playback state.
class BoatMediaStatus {
  final BoatMediaState state;

  /// Current position. Always [Duration.zero] for streaming PCM.
  final Duration position;

  /// Total duration, or `null` when unknown (streaming PCM).
  final Duration? duration;

  /// Volume in the range 0.0–1.0.
  final double volume;

  final BoatMediaSourceKind sourceKind;

  /// Whether the active source loops.
  final bool loop;

  const BoatMediaStatus({
    required this.state,
    required this.position,
    required this.duration,
    required this.volume,
    required this.sourceKind,
    required this.loop,
  });

  /// Deserializes from a platform channel map.
  ///
  /// A negative `durationMs` means "unknown" and maps to `null` rather than a
  /// negative [Duration].
  factory BoatMediaStatus.fromMap(Map<String, dynamic> map) {
    final durationMs = map['durationMs'] as int? ?? -1;
    return BoatMediaStatus(
      state: _stateFromString(map['state'] as String?),
      position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
      duration: durationMs < 0 ? null : Duration(milliseconds: durationMs),
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      sourceKind: BoatMediaSourceKind.fromString(map['sourceKind'] as String?),
      loop: map['loop'] as bool? ?? false,
    );
  }

  static BoatMediaState _stateFromString(String? value) {
    for (final state in BoatMediaState.values) {
      if (state.name == value) return state;
    }
    return BoatMediaState.idle;
  }

  @override
  String toString() =>
      'BoatMediaStatus($state, pos: $position, dur: $duration, '
      'vol: $volume, src: $sourceKind, loop: $loop)';
}
