import 'package:boat/boat.dart';
import 'package:boat_diagnostics/services/mock_audio_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('asymmetric playback rate config', () {
    test('capture stays 16 kHz while playback is 24 kHz', () {
      final config = BoatConfig(
        sampleRate: 16000,
        playbackSampleRate: 24000,
      );
      expect(config.sampleRate, 16000);
      expect(config.effectivePlaybackSampleRate, 24000);
    });

    test('channel map carries both rates', () {
      final map = BoatConfig(
        sampleRate: 16000,
        playbackSampleRate: 24000,
      ).toMap();
      expect(map['sampleRate'], 16000);
      expect(map['playbackSampleRate'], 24000);
    });

    test('omitting the playback rate keeps the symmetric default', () {
      final map = BoatConfig(sampleRate: 16000).toMap();
      expect(map['playbackSampleRate'], 16000);
    });
  });

  group('asset selection', () {
    test('24 kHz playback selects the 24 kHz clip', () {
      expect(
        MockAudioServer.assetForPlaybackRate(24000),
        'assets/pcm/ai_response_24k.pcm',
      );
    });

    test('16 kHz playback selects the 16 kHz clip', () {
      expect(
        MockAudioServer.assetForPlaybackRate(16000),
        'assets/pcm/ai_response_short.pcm',
      );
    });
  });
}
