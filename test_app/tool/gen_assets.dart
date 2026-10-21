// Generates raw PCM test assets for the real-world test app.
// Run from test_app/: `dart run tool/gen_assets.dart`.
//
// Produces three clips in assets/pcm/:
//   ai_response_short.pcm     ~3s  — 16 kHz, 300-700Hz warble (short AI reply)
//   ai_response_long.pcm      ~10s — 16 kHz, 200-900Hz sweep (sustained AEC stress)
//   ai_response_24k.pcm       ~3s  — 24 kHz, same warble (asymmetric-rate scenario)
//
// Raw PCM (no WAV header) matches engine.playRaw(Uint8List) expectations.
// The 24 kHz clip is synthesized at 24 kHz — never resampled from the 16 kHz
// one — so the asymmetric scenario proves the real playback path.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int bitsPerSample = 16;
const int channels = 1;

Uint8List synthesize(
  Duration duration,
  double Function(double t) wave, {
  int sampleRate = 16000,
}) {
  final samples = (sampleRate * duration.inMilliseconds / 1000).round();
  final bytes = ByteData(samples * bitsPerSample ~/ 8 * channels);
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    final v = (32767 * 0.25 * wave(t)).round().clamp(-32768, 32767);
    bytes.setInt16(i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  final outDir = Directory('assets/pcm');
  outDir.createSync(recursive: true);

  // Short: 3s warble between 300-700Hz, 0.5s period.
  final short = synthesize(
    const Duration(seconds: 3),
    (t) {
      final f = 500 + 200 * sin(2 * pi * 2 * t);
      return sin(2 * pi * f * t);
    },
  );
  File('${outDir.path}/ai_response_short.pcm').writeAsBytesSync(short);
  stdout.writeln('Wrote ai_response_short.pcm (${short.length} bytes)');

  // Long: 10s sweep 200-900Hz over 2s period.
  final long = synthesize(
    const Duration(seconds: 10),
    (t) {
      final f = 550 + 350 * sin(2 * pi * 0.5 * t);
      return sin(2 * pi * f * t);
    },
  );
  File('${outDir.path}/ai_response_long.pcm').writeAsBytesSync(long);
  stdout.writeln('Wrote ai_response_long.pcm (${long.length} bytes)');

  // 24 kHz: same warble, synthesized at 24 kHz for the asymmetric-rate scenario.
  final wide = synthesize(
    const Duration(seconds: 3),
    (t) {
      final f = 500 + 200 * sin(2 * pi * 2 * t);
      return sin(2 * pi * f * t);
    },
    sampleRate: 24000,
  );
  File('${outDir.path}/ai_response_24k.pcm').writeAsBytesSync(wide);
  stdout.writeln('Wrote ai_response_24k.pcm (${wide.length} bytes)');
}