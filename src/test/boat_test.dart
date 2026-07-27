import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:boat/boat.dart';
import 'package:boat/boat_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBoatPlatform with MockPlatformInterfaceMixin implements BoatPlatform {
  @override
  BoatState state = BoatState.idle;

  @override
  AudioRoute currentRoute = AudioRoute.speaker;

  @override
  Stream<BoatEvent> get events => const Stream.empty();

  @override
  Stream<AudioFrame> get captureFrames => const Stream.empty();

  @override
  Future<void> start(BoatConfig config) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> reconfigure(BoatConfig config) async {}
  @override
  void play(Uint8List pcm) {}
  @override
  Future<void> flushPlayback() async {}
  @override
  Future<void> setRoute(AudioRoute route) async {}
  @override
  Future<BoatDiagnostics> getDiagnostics() async => const BoatDiagnostics(
        deviceModel: 'mock',
        osVersion: '0',
        audioSessionId: -1,
        effectStatus: {},
        currentRoute: AudioRoute.speaker,
        availableRoutes: [],
        captureFrameCount: 0,
        playbackFrameCount: 0,
        uptime: Duration.zero,
      );
}

void main() {
  final BoatPlatform initialPlatform = BoatPlatform.instance;

  test('$MethodChannelBoat is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBoat>());
  });

  test('platform interface can be overridden', () {
    final mock = MockBoatPlatform();
    BoatPlatform.instance = mock;
    expect(BoatPlatform.instance, same(mock));
    BoatPlatform.instance = MethodChannelBoat();
  });

  group('BoatConfig', () {
    test('defaults are correct', () {
      const config = BoatConfig();
      expect(config.sampleRate, 16000);
      expect(config.channelCount, 1);
      expect(config.bitsPerSample, 16);
      expect(config.bufferDurationMs, 20);
      expect(config.aec, isTrue);
      expect(config.agc, isTrue);
      expect(config.noiseSuppression, isTrue);
      expect(config.speakerMode, isTrue);
      expect(config.preferredRoute, AudioRoute.speaker);
    });

    test('toMap serializes all fields', () {
      const config = BoatConfig(sampleRate: 48000, aec: false);
      final map = config.toMap();
      expect(map['sampleRate'], 48000);
      expect(map['aec'], isFalse);
      expect(map['preferredRoute'], 'speaker');
    });

    test('builder produces equivalent config', () {
      final built = BoatConfig.builder()
          .sampleRate(44100)
          .channelCount(2)
          .bufferDurationMs(40)
          .aec(false)
          .preferredRoute(AudioRoute.bluetooth)
          .build();

      expect(built.sampleRate, 44100);
      expect(built.channelCount, 2);
      expect(built.bufferDurationMs, 40);
      expect(built.aec, isFalse);
      expect(built.preferredRoute, AudioRoute.bluetooth);
    });

    test('equality and hashCode', () {
      const a = BoatConfig();
      const b = BoatConfig();
      const c = BoatConfig(sampleRate: 48000);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('AudioRoute', () {
    test('fromString parses all values', () {
      for (final route in AudioRoute.values) {
        expect(AudioRoute.fromString(route.name), route);
      }
    });

    test('fromString throws on unknown', () {
      expect(() => AudioRoute.fromString('invalid'), throwsArgumentError);
    });

    test('toChannelString round-trips', () {
      for (final route in AudioRoute.values) {
        expect(AudioRoute.fromString(route.toChannelString()), route);
      }
    });
  });

  group('AudioFrame', () {
    test('duration computed correctly', () {
      // 16000 Hz, mono, 16-bit → 32000 bytes/sec → 640 bytes = 20ms
      final frame = AudioFrame(
        pcm: Uint8List(640),
        sequenceNumber: 0,
        timestamp: Duration.zero,
        sampleRate: 16000,
        channelCount: 1,
      );
      expect(frame.duration, const Duration(milliseconds: 20));
      expect(frame.byteLength, 640);
    });
  });

  group('BoatDiagnostics', () {
    test('fromMap parses correctly', () {
      final diag = BoatDiagnostics.fromMap({
        'deviceModel': 'Pixel 8',
        'osVersion': '15',
        'audioSessionId': 42,
        'effectStatus': {
          'aec': {'supported': true, 'available': true, 'active': true},
        },
        'currentRoute': 'speaker',
        'availableRoutes': ['speaker', 'bluetooth'],
        'captureFrameCount': 100,
        'playbackFrameCount': 50,
        'uptimeMs': 5000,
      });

      expect(diag.deviceModel, 'Pixel 8');
      expect(diag.audioSessionId, 42);
      expect(diag.effectStatus[AudioEffectType.aec]?.active, isTrue);
      expect(diag.currentRoute, AudioRoute.speaker);
      expect(diag.availableRoutes, [AudioRoute.speaker, AudioRoute.bluetooth]);
      expect(diag.uptime, const Duration(milliseconds: 5000));
    });

    test('fromMap handles missing fields gracefully', () {
      final diag = BoatDiagnostics.fromMap({});
      expect(diag.deviceModel, '');
      expect(diag.audioSessionId, -1);
      expect(diag.effectStatus, isEmpty);
    });
  });

  group('Exceptions', () {
    test('toString includes code when present', () {
      const e = BoatConfigException('bad config', code: 'INVALID_RATE');
      expect(e.toString(), contains('INVALID_RATE'));
      expect(e.toString(), contains('bad config'));
    });

    test('hierarchy is correct', () {
      expect(const BoatPermissionException('x'), isA<BoatException>());
      expect(const BoatNativeException('x'), isA<BoatException>());
      expect(const BoatStateException('x'), isA<BoatException>());
    });
  });
}
