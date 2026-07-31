import 'dart:typed_data';

/// A single captured audio frame with metadata.
///
/// Frames are delivered via [BoatEngine.captureFrames] as a stream.
/// PCM data is 16-bit signed little-endian.
class AudioFrame {
  /// Raw PCM bytes (16-bit signed, little-endian).
  final Uint8List pcm;

  /// Monotonically increasing frame counter since engine start.
  final int sequenceNumber;

  /// Time since engine start when this frame was captured.
  final Duration timestamp;

  /// Sample rate of this frame in Hz.
  final int sampleRate;

  /// Number of audio channels in this frame.
  final int channelCount;

  const AudioFrame({
    required this.pcm,
    required this.sequenceNumber,
    required this.timestamp,
    required this.sampleRate,
    required this.channelCount,
  });

  /// Length of [pcm] in bytes.
  int get byteLength => pcm.length;

  /// Duration of audio in this frame, computed from byte length and format.
  ///
  /// Returns [Duration.zero] when [sampleRate] or [channelCount] is zero
  /// to avoid division-by-zero.
  Duration get duration {
    if (sampleRate == 0 || channelCount == 0) return Duration.zero;
    const bytesPerSample = 2; // 16-bit
    final totalSamples = pcm.length ~/ (bytesPerSample * channelCount);
    final microseconds = (totalSamples * 1000000) ~/ sampleRate;
    return Duration(microseconds: microseconds);
  }

  @override
  String toString() =>
      'AudioFrame(seq: $sequenceNumber, ts: $timestamp, '
      'bytes: $byteLength, rate: $sampleRate, ch: $channelCount)';
}
