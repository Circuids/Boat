import 'dart:async';
import 'dart:typed_data';

import 'package:boat/boat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Minimal platform stub — the rate guard is pure Dart, so no native behavior
/// is needed beyond a startable engine.
class _MockPlatform with MockPlatformInterfaceMixin implements BoatPlatform {
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

  @override
  Future<PermissionStatus> checkPermission(PermissionType type) async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestPermission(PermissionType type) async =>
      PermissionStatus.granted;

  @override
  Future<void> openAppSettings() async {}
}

void main() {
  group('BoatConfig playbackSampleRate', () {
    test('defaults to null and resolves to sampleRate', () {
      final config = BoatConfig();
      expect(config.playbackSampleRate, isNull);
      expect(config.effectivePlaybackSampleRate, 16000);
    });

    test('explicit rate overrides the capture rate', () {
      final config = BoatConfig(sampleRate: 16000, playbackSampleRate: 24000);
      expect(config.sampleRate, 16000);
      expect(config.effectivePlaybackSampleRate, 24000);
    });

    test('toMap emits the effective rate, never null', () {
      expect(
        BoatConfig(sampleRate: 16000).toMap()['playbackSampleRate'],
        16000,
      );
      expect(
        BoatConfig(
          sampleRate: 16000,
          playbackSampleRate: 24000,
        ).toMap()['playbackSampleRate'],
        24000,
      );
    });

    test('toMap keeps sampleRate as the capture rate', () {
      final map = BoatConfig(
        sampleRate: 16000,
        playbackSampleRate: 24000,
      ).toMap();
      expect(map['sampleRate'], 16000);
    });

    test('null and an explicit equal value compare equal', () {
      expect(
        BoatConfig(sampleRate: 16000),
        BoatConfig(sampleRate: 16000, playbackSampleRate: 16000),
      );
      expect(
        BoatConfig(sampleRate: 16000).hashCode,
        BoatConfig(sampleRate: 16000, playbackSampleRate: 16000).hashCode,
      );
    });

    test('different effective rates are not equal', () {
      expect(
        BoatConfig(sampleRate: 16000, playbackSampleRate: 24000),
        isNot(BoatConfig(sampleRate: 16000)),
      );
    });

    test('rejects non-positive playbackSampleRate', () {
      // Debug builds hit the assert first; release throws ArgumentError.
      // Both are Error subtypes.
      expect(() => BoatConfig(playbackSampleRate: 0), throwsA(isA<Error>()));
      expect(() => BoatConfig(playbackSampleRate: -1), throwsA(isA<Error>()));
    });

    test('toString reports the effective playback rate', () {
      final s = BoatConfig(
        sampleRate: 16000,
        playbackSampleRate: 24000,
      ).toString();
      expect(s, contains('playbackSampleRate: 24000'));
    });
  });

  group('BoatConfigBuilder playbackSampleRate', () {
    test('builds an asymmetric config', () {
      final config = BoatConfig.builder()
          .sampleRate(16000)
          .playbackSampleRate(24000)
          .build();
      expect(config.sampleRate, 16000);
      expect(config.effectivePlaybackSampleRate, 24000);
    });

    test('omitting it leaves playback equal to capture', () {
      final config = BoatConfig.builder().sampleRate(16000).build();
      expect(config.playbackSampleRate, isNull);
      expect(config.effectivePlaybackSampleRate, 16000);
    });
  });

  group('BoatDiagnostics sample rates', () {
    test('parses both rates from the channel map', () {
      final d = BoatDiagnostics.fromMap({
        'captureSampleRate': 16000,
        'playbackSampleRate': 24000,
      });
      expect(d.captureSampleRate, 16000);
      expect(d.playbackSampleRate, 24000);
    });

    test('defaults to 0 when absent', () {
      final d = BoatDiagnostics.fromMap({});
      expect(d.captureSampleRate, 0);
      expect(d.playbackSampleRate, 0);
    });
  });

  group('BoatEngine play(AudioFrame) rate guard', () {
    late _MockPlatform platform;
    late BoatEngine engine;

    setUp(() {
      platform = _MockPlatform();
      engine = BoatEngine(platform: platform);
    });

    tearDown(() async {
      if (engine.state == BoatState.running ||
          engine.state == BoatState.paused) {
        await engine.stop();
      }
      await engine.dispose();
    });

    AudioFrame frameAt(int rate) => AudioFrame(
      pcm: Uint8List(320),
      sequenceNumber: 1,
      timestamp: Duration.zero,
      sampleRate: rate,
      channelCount: 1,
    );

    test('matching rate emits no warning', () async {
      final warnings = <BoatWarning>[];
      engine.events
          .where((e) => e is BoatWarning)
          .cast<BoatWarning>()
          .listen(warnings.add);

      await engine.start(
        BoatConfig(sampleRate: 16000, playbackSampleRate: 24000),
      );
      engine.play(frameAt(24000));
      await Future<void>.delayed(Duration.zero);

      expect(
        warnings.where((w) => w.code == 'PLAYBACK_RATE_MISMATCH'),
        isEmpty,
      );
    });

    test('mismatched rate warns exactly once for two frames', () async {
      final warnings = <BoatWarning>[];
      engine.events
          .where((e) => e is BoatWarning)
          .cast<BoatWarning>()
          .listen(warnings.add);

      await engine.start(
        BoatConfig(sampleRate: 16000, playbackSampleRate: 24000),
      );
      engine.play(frameAt(16000));
      engine.play(frameAt(16000));
      await Future<void>.delayed(Duration.zero);

      final mismatches = warnings
          .where((w) => w.code == 'PLAYBACK_RATE_MISMATCH')
          .toList();
      expect(mismatches, hasLength(1));
      expect(mismatches.single.message, contains('16000'));
      expect(mismatches.single.message, contains('24000'));
    });

    test('warning resets after reconfigure', () async {
      final warnings = <BoatWarning>[];
      engine.events
          .where((e) => e is BoatWarning)
          .cast<BoatWarning>()
          .listen(warnings.add);

      await engine.start(
        BoatConfig(sampleRate: 16000, playbackSampleRate: 24000),
      );
      engine.play(frameAt(16000));
      await Future<void>.delayed(Duration.zero);

      await engine.reconfigure(
        BoatConfig(sampleRate: 16000, playbackSampleRate: 24000),
      );
      engine.play(frameAt(16000));
      await Future<void>.delayed(Duration.zero);

      expect(
        warnings.where((w) => w.code == 'PLAYBACK_RATE_MISMATCH'),
        hasLength(2),
      );
    });

    test('symmetric config never warns', () async {
      final warnings = <BoatWarning>[];
      engine.events
          .where((e) => e is BoatWarning)
          .cast<BoatWarning>()
          .listen(warnings.add);

      await engine.start(BoatConfig(sampleRate: 16000));
      engine.play(frameAt(16000));
      await Future<void>.delayed(Duration.zero);

      expect(
        warnings.where((w) => w.code == 'PLAYBACK_RATE_MISMATCH'),
        isEmpty,
      );
    });
  });
}
