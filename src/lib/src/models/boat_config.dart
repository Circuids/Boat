import '../common/audio_route.dart';
import 'boat_config_builder.dart';

/// Immutable configuration for [BoatEngine].
///
/// All parameters have sensible defaults for voice communication.
/// Use [BoatConfig.builder] for fluent construction.
class BoatConfig {
  /// Audio sample rate in Hz. Default: 16000.
  final int sampleRate;

  /// Number of audio channels. Default: 1 (mono).
  final int channelCount;

  /// Bits per sample. Default: 16.
  final int bitsPerSample;

  /// Target buffer duration in milliseconds. Default: 20.
  final int bufferDurationMs;

  /// Enable acoustic echo cancellation. Default: true.
  final bool aec;

  /// Enable automatic gain control. Default: true.
  final bool agc;

  /// Enable noise suppression. Default: true.
  final bool noiseSuppression;

  /// Use speaker (true) or earpiece (false) for playback. Default: true.
  final bool speakerMode;

  /// Preferred audio output route. Default: [AudioRoute.speaker].
  final AudioRoute preferredRoute;

  BoatConfig({
    this.sampleRate = 16000,
    this.channelCount = 1,
    this.bitsPerSample = 16,
    this.bufferDurationMs = 20,
    this.aec = true,
    this.agc = true,
    this.noiseSuppression = true,
    this.speakerMode = true,
    this.preferredRoute = AudioRoute.speaker,
  }) : assert(sampleRate > 0, 'sampleRate must be positive'),
       assert(channelCount > 0, 'channelCount must be positive'),
       assert(bitsPerSample == 16, 'Only 16-bit PCM is supported in v1.0'),
       assert(bufferDurationMs > 0, 'bufferDurationMs must be positive'),
       assert(
         bufferDurationMs >= 5 && bufferDurationMs <= 100,
         'bufferDurationMs must be between 5 and 100',
       ) {
    // Runtime validation — asserts are stripped in release mode, so the
    // constructor body must throw to catch invalid configs in production.
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'must be positive');
    }
    if (channelCount <= 0) {
      throw ArgumentError.value(
        channelCount,
        'channelCount',
        'must be positive',
      );
    }
    if (bitsPerSample != 16) {
      throw ArgumentError.value(
        bitsPerSample,
        'bitsPerSample',
        'only 16-bit PCM is supported in v1.0',
      );
    }
    if (bufferDurationMs <= 0) {
      throw ArgumentError.value(
        bufferDurationMs,
        'bufferDurationMs',
        'must be positive',
      );
    }
    if (bufferDurationMs < 5 || bufferDurationMs > 100) {
      throw ArgumentError.value(
        bufferDurationMs,
        'bufferDurationMs',
        'must be between 5 and 100',
      );
    }
  }

  /// Creates a [BoatConfigBuilder] for fluent configuration.
  static BoatConfigBuilder builder() => BoatConfigBuilder();

  /// Serializes this config to a map for platform channel transport.
  Map<String, dynamic> toMap() => {
    'sampleRate': sampleRate,
    'channelCount': channelCount,
    'bitsPerSample': bitsPerSample,
    'bufferDurationMs': bufferDurationMs,
    'aec': aec,
    'agc': agc,
    'noiseSuppression': noiseSuppression,
    'speakerMode': speakerMode,
    'preferredRoute': preferredRoute.toChannelString(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoatConfig &&
          sampleRate == other.sampleRate &&
          channelCount == other.channelCount &&
          bitsPerSample == other.bitsPerSample &&
          bufferDurationMs == other.bufferDurationMs &&
          aec == other.aec &&
          agc == other.agc &&
          noiseSuppression == other.noiseSuppression &&
          speakerMode == other.speakerMode &&
          preferredRoute == other.preferredRoute;

  @override
  int get hashCode => Object.hash(
    sampleRate,
    channelCount,
    bitsPerSample,
    bufferDurationMs,
    aec,
    agc,
    noiseSuppression,
    speakerMode,
    preferredRoute,
  );

  @override
  String toString() =>
      'BoatConfig(sampleRate: $sampleRate, channels: $channelCount, '
      'bits: $bitsPerSample, buffer: ${bufferDurationMs}ms, '
      'aec: $aec, agc: $agc, ns: $noiseSuppression, '
      'speaker: $speakerMode, route: $preferredRoute)';
}
