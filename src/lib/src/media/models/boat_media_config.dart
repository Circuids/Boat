/// Format for streaming PCM delivered through `BoatMediaPlayer.playPcm`.
///
/// Only consulted when no file source has established a format. WAV sources
/// take their format from the file header, so this config is ignored for them.
class BoatMediaConfig {
  /// Sample rate in Hz. Default: 48000.
  final int sampleRate;

  /// Number of channels. Default: 2 (stereo).
  final int channelCount;

  /// Bits per sample. Default: 16.
  final int bitsPerSample;

  BoatMediaConfig({
    this.sampleRate = 48000,
    this.channelCount = 2,
    this.bitsPerSample = 16,
  }) : assert(sampleRate > 0, 'sampleRate must be positive'),
       assert(channelCount > 0, 'channelCount must be positive'),
       assert(bitsPerSample == 16, 'Only 16-bit PCM is supported') {
    // Asserts are stripped in release mode; the constructor body must throw
    // so invalid configs fail in production too.
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
        'only 16-bit PCM is supported',
      );
    }
  }

  /// Serializes to a platform channel map.
  Map<String, dynamic> toMap() => {
    'sampleRate': sampleRate,
    'channelCount': channelCount,
    'bitsPerSample': bitsPerSample,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoatMediaConfig &&
          sampleRate == other.sampleRate &&
          channelCount == other.channelCount &&
          bitsPerSample == other.bitsPerSample;

  @override
  int get hashCode => Object.hash(sampleRate, channelCount, bitsPerSample);

  @override
  String toString() =>
      'BoatMediaConfig(rate: $sampleRate, channels: $channelCount, '
      'bits: $bitsPerSample)';
}
