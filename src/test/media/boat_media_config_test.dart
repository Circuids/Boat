import 'package:boat/boat_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoatMediaConfig defaults', () {
    test('uses 48 kHz stereo 16-bit', () {
      final config = BoatMediaConfig();
      expect(config.sampleRate, 48000);
      expect(config.channelCount, 2);
      expect(config.bitsPerSample, 16);
    });

    test('toMap emits the channel keys', () {
      final map = BoatMediaConfig(
        sampleRate: 16000,
        channelCount: 1,
      ).toMap();
      expect(map, {
        'sampleRate': 16000,
        'channelCount': 1,
        'bitsPerSample': 16,
      });
    });
  });

  group('BoatMediaConfig runtime validation', () {
    // In debug builds the constructor's asserts fire first; in release the
    // constructor body throws ArgumentError. Both are Error subtypes, so the
    // test asserts on Error rather than pinning the debug-mode type.
    test('throws on non-positive sampleRate', () {
      expect(() => BoatMediaConfig(sampleRate: 0), throwsA(isA<Error>()));
      expect(() => BoatMediaConfig(sampleRate: -1), throwsA(isA<Error>()));
    });

    test('throws on non-positive channelCount', () {
      expect(() => BoatMediaConfig(channelCount: 0), throwsA(isA<Error>()));
    });

    test('throws on non-16-bit', () {
      expect(() => BoatMediaConfig(bitsPerSample: 8), throwsA(isA<Error>()));
      expect(() => BoatMediaConfig(bitsPerSample: 24), throwsA(isA<Error>()));
    });

    test('valid config does not throw', () {
      expect(
        () => BoatMediaConfig(sampleRate: 8000, channelCount: 1),
        returnsNormally,
      );
    });
  });

  group('BoatMediaConfig equality', () {
    test('equal when all fields match', () {
      expect(BoatMediaConfig(), BoatMediaConfig());
      expect(BoatMediaConfig().hashCode, BoatMediaConfig().hashCode);
    });

    test('not equal when a field differs', () {
      expect(BoatMediaConfig(sampleRate: 16000), isNot(BoatMediaConfig()));
    });
  });

  group('BoatMediaStatus.fromMap', () {
    test('parses a full map', () {
      final status = BoatMediaStatus.fromMap({
        'state': 'playing',
        'positionMs': 1500,
        'durationMs': 3000,
        'volume': 0.5,
        'sourceKind': 'file',
        'loop': true,
      });
      expect(status.state, BoatMediaState.playing);
      expect(status.position, const Duration(milliseconds: 1500));
      expect(status.duration, const Duration(milliseconds: 3000));
      expect(status.volume, 0.5);
      expect(status.sourceKind, BoatMediaSourceKind.file);
      expect(status.loop, isTrue);
    });

    test('negative durationMs maps to null (unknown)', () {
      final status = BoatMediaStatus.fromMap({
        'state': 'playing',
        'durationMs': -1,
      });
      expect(status.duration, isNull);
    });

    test('unknown state falls back to idle', () {
      final status = BoatMediaStatus.fromMap({'state': 'bogus'});
      expect(status.state, BoatMediaState.idle);
    });

    test('unknown sourceKind falls back to none', () {
      final status = BoatMediaStatus.fromMap({'sourceKind': 'bogus'});
      expect(status.sourceKind, BoatMediaSourceKind.none);
    });

    test('empty map yields safe defaults', () {
      final status = BoatMediaStatus.fromMap({});
      expect(status.state, BoatMediaState.idle);
      expect(status.position, Duration.zero);
      expect(status.duration, isNull);
      expect(status.volume, 1.0);
      expect(status.sourceKind, BoatMediaSourceKind.none);
      expect(status.loop, isFalse);
    });
  });
}
