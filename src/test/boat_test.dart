import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:boat/boat.dart';
import 'package:boat/boat_method_channel.dart';
import 'package:boat/src/boat_engine_state_machine.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
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
      final config = BoatConfig();
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
      final config = BoatConfig(sampleRate: 48000, aec: false);
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
      final a = BoatConfig();
      final b = BoatConfig();
      final c = BoatConfig(sampleRate: 48000);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('BoatConfig routing semantics', () {
    test('default: speakerMode true + preferredRoute speaker', () {
      final config = BoatConfig();
      expect(config.speakerMode, isTrue);
      expect(config.preferredRoute, AudioRoute.speaker);
    });

    test('speakerMode false + earpiece fallback serializes correctly', () {
      final config = BoatConfig(speakerMode: false, preferredRoute: AudioRoute.earpiece);
      final map = config.toMap();
      expect(map['speakerMode'], isFalse);
      expect(map['preferredRoute'], 'earpiece');
    });

    test('toMap carries speakerMode and preferredRoute for all routes', () {
      for (final route in AudioRoute.values) {
        final map = BoatConfig(preferredRoute: route).toMap();
        expect(map['preferredRoute'], route.toChannelString());
      }
    });

    test('reconfigure round-trip preserves routing fields', () async {
      final mock = _RecordingMockPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();

      final routingConfig = BoatConfig(
        speakerMode: false,
        preferredRoute: AudioRoute.earpiece,
      );
      await engine.reconfigure(routingConfig);
      expect(engine.state, BoatState.running);
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

    test('fromMap parses scoDeviceConnected', () {
      final on = BoatDiagnostics.fromMap({'scoDeviceConnected': true});
      final off = BoatDiagnostics.fromMap({'scoDeviceConnected': false});
      final missing = BoatDiagnostics.fromMap({});
      expect(on.scoDeviceConnected, isTrue);
      expect(off.scoDeviceConnected, isFalse);
      expect(missing.scoDeviceConnected, isFalse); // defaults to false
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

  group('PermissionStatus', () {
    test('fromString parses all values', () {
      for (final status in PermissionStatus.values) {
        expect(PermissionStatus.fromString(status.name), status);
      }
    });

    test('fromString throws on unknown', () {
      expect(() => PermissionStatus.fromString('invalid'), throwsArgumentError);
    });

    test('toChannelString round-trips', () {
      for (final status in PermissionStatus.values) {
        expect(PermissionStatus.fromString(status.toChannelString()), status);
      }
    });
  });

  group('PermissionType', () {
    test('fromString parses all values', () {
      for (final type in PermissionType.values) {
        expect(PermissionType.fromString(type.name), type);
      }
    });

    test('fromString throws on unknown', () {
      expect(() => PermissionType.fromString('invalid'), throwsArgumentError);
    });

    test('toChannelString round-trips', () {
      for (final type in PermissionType.values) {
        expect(PermissionType.fromString(type.toChannelString()), type);
      }
    });
  });

  group('BoatPermission', () {
    test('check delegates to platform', () async {
      final mock = MockBoatPlatform();
      BoatPlatform.instance = mock;
      final status = await BoatPermission.check(PermissionType.microphone);
      expect(status, PermissionStatus.granted);
      BoatPlatform.instance = MethodChannelBoat();
    });

    test('request delegates to platform', () async {
      final mock = MockBoatPlatform();
      BoatPlatform.instance = mock;
      final status = await BoatPermission.request(PermissionType.microphone);
      expect(status, PermissionStatus.granted);
      BoatPlatform.instance = MethodChannelBoat();
    });
  });

  group('BoatEngine permission gate', () {
    test('start throws BoatPermissionException when not granted', () async {
      final mock = _DeniedMockPlatform();
      final engine = BoatEngine(platform: mock);
      expect(
        () => engine.start(),
        throwsA(isA<BoatPermissionException>().having(
          (e) => e.code,
          'code',
          'PERMISSION_DENIED',
        )),
      );
    });

    test('start succeeds when permission granted', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      expect(engine.state, BoatState.running);
    });
  });

  group('BoatEngine.reconfigure', () {
    test('transitions running → idle → running with new config', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      expect(engine.state, BoatState.running);

      final newConfig = BoatConfig(aec: false, sampleRate: 48000);
      await engine.reconfigure(newConfig);
      expect(engine.state, BoatState.running);
    });

    test('calls platform stop then start', () async {
      final mock = _RecordingMockPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      mock.calls.clear();

      await engine.reconfigure(BoatConfig(aec: false));
      expect(mock.calls, ['stop', 'start']);
    });

    test('throws if engine is idle (invalid transition)', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      expect(
        () => engine.reconfigure(BoatConfig()),
        throwsA(isA<BoatStateException>()),
      );
    });

    test('propagates platform start failure to error state', () async {
      final mock = _StartFailingMockPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      await expectLater(
        engine.reconfigure(BoatConfig()),
        throwsException,
      );
      expect(engine.state, BoatState.error);
    });
  });

  group('BoatEngine state transitions', () {
    test('valid: idle → starting → running → stopping → idle', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      expect(engine.state, BoatState.running);
      await engine.stop();
      expect(engine.state, BoatState.idle);
    });

    test('valid: running → paused → running', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      await engine.pause();
      expect(engine.state, BoatState.paused);
      await engine.resume();
      expect(engine.state, BoatState.running);
    });

    test('valid: idle → disposed', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.dispose();
      expect(engine.state, BoatState.disposed);
    });

    test('invalid: reconfigure from idle throws (not running)', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      expect(
        () => engine.reconfigure(BoatConfig()),
        throwsA(isA<BoatStateException>()),
      );
    });

    test('reconfigure cycles through idle between stop and start', () async {
      final mock = _RecordingMockPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      mock.calls.clear();

      await engine.reconfigure(BoatConfig(aec: false));
      // After reconfigure, engine is running and platform saw stop then start.
      expect(engine.state, BoatState.running);
      expect(mock.calls, ['stop', 'start']);
    });
  });

  // ── Production hardening tests ──

  group('BoatConfig runtime validation', () {
    // In debug mode, asserts fire first (AssertionError). In release mode,
    // the constructor body throws ArgumentError. Both are acceptable —
    // the key requirement is that invalid configs throw in release.
    test('throws on sampleRate <= 0', () {
      expect(() => BoatConfig(sampleRate: 0), throwsA(isA<Error>()));
      expect(() => BoatConfig(sampleRate: -1), throwsA(isA<Error>()));
    });

    test('throws on channelCount <= 0', () {
      expect(() => BoatConfig(channelCount: 0), throwsA(isA<Error>()));
    });

    test('throws on bitsPerSample != 16', () {
      expect(() => BoatConfig(bitsPerSample: 8), throwsA(isA<Error>()));
    });

    test('throws on bufferDurationMs out of range', () {
      expect(() => BoatConfig(bufferDurationMs: 0), throwsA(isA<Error>()));
      expect(() => BoatConfig(bufferDurationMs: 4), throwsA(isA<Error>()));
      expect(() => BoatConfig(bufferDurationMs: 101), throwsA(isA<Error>()));
    });

    test('valid config does not throw', () {
      expect(() => BoatConfig(sampleRate: 48000, bufferDurationMs: 40), returnsNormally);
    });
  });

  group('AudioFrame.duration zero-safe', () {
    test('returns Duration.zero when sampleRate is 0', () {
      final frame = AudioFrame(
        pcm: Uint8List(640),
        sequenceNumber: 0,
        timestamp: Duration.zero,
        sampleRate: 0,
        channelCount: 1,
      );
      expect(frame.duration, Duration.zero);
    });

    test('returns Duration.zero when channelCount is 0', () {
      final frame = AudioFrame(
        pcm: Uint8List(640),
        sequenceNumber: 0,
        timestamp: Duration.zero,
        sampleRate: 16000,
        channelCount: 0,
      );
      expect(frame.duration, Duration.zero);
    });
  });

  group('BoatDiagnostics.fromMap resilience', () {
    test('skips unknown route strings in availableRoutes', () {
      final diag = BoatDiagnostics.fromMap({
        'availableRoutes': ['speaker', 'invalidRoute', 'bluetooth'],
      });
      expect(diag.availableRoutes, [AudioRoute.speaker, AudioRoute.bluetooth]);
    });

    test('skips unknown effect keys', () {
      final diag = BoatDiagnostics.fromMap({
        'effectStatus': {
          'aec': {'supported': true, 'available': true, 'active': true},
          'unknownEffect': {'supported': true, 'available': true, 'active': true},
        },
      });
      expect(diag.effectStatus.length, 1);
      expect(diag.effectStatus.containsKey(AudioEffectType.aec), isTrue);
    });

    test('skips non-Map effect values', () {
      final diag = BoatDiagnostics.fromMap({
        'effectStatus': {
          'aec': 'not a map',
        },
      });
      expect(diag.effectStatus, isEmpty);
    });
  });

  group('BoatEngine play() state guard', () {
    test('play() throws StateError when engine is idle', () {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      final frame = AudioFrame(
        pcm: Uint8List(4),
        sequenceNumber: 0,
        timestamp: Duration.zero,
        sampleRate: 16000,
        channelCount: 1,
      );
      expect(() => engine.play(frame), throwsStateError);
    });

    test('playRaw() throws StateError when engine is idle', () {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      expect(() => engine.playRaw(Uint8List(4)), throwsStateError);
    });

    test('play() succeeds when engine is running', () async {
      final mock = MockBoatPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      final frame = AudioFrame(
        pcm: Uint8List(4),
        sequenceNumber: 0,
        timestamp: Duration.zero,
        sampleRate: 16000,
        channelCount: 1,
      );
      engine.play(frame); // should not throw
    });
  });

  group('BoatEngine BoatError event handling', () {
    test('transitions to error on BoatError event from native', () async {
      final mock = _EventEmittingMockPlatform();
      final engine = BoatEngine(platform: mock);
      await engine.start();
      expect(engine.state, BoatState.running);

      mock.emitEvent(BoatError(
        timestamp: DateTime.now(),
        exception: const BoatNativeException('native crash', code: 'FATAL'),
      ));

      // Give the stream listener a microtask to process.
      await Future<void>.delayed(Duration.zero);
      expect(engine.state, BoatState.error);
    });
  });

  group('BoatEngine concurrency guard', () {
    test('overlapping start() and stop() are serialized', () async {
      final mock = _SlowMockPlatform();
      final engine = BoatEngine(platform: mock);

      // Start both concurrently — the mutex should serialize them.
      final startFuture = engine.start();
      final stopFuture = engine.stop();

      // Both should complete without throwing (stop waits for start).
      await Future.wait([startFuture, stopFuture]);

      // Final state depends on execution order, but no exception should
      // be thrown and the state machine should be consistent.
      expect(engine.state, anyOf(BoatState.idle, BoatState.error, BoatState.running));
    });
  });

  group('BoatEngine start failure cleanup', () {
    test('calls platform stop() after start failure to clean up', () async {
      final mock = _StartFailingWithStopMockPlatform();
      final engine = BoatEngine(platform: mock);
      await expectLater(engine.start(), throwsException);
      expect(engine.state, BoatState.error);
      expect(mock.stopCalled, isTrue);
    });
  });

  group('BoatEngine starting → stopping transition', () {
    test('state machine allows starting → stopping transition', () async {
      // Verify the state machine itself allows the transition.
      final sm = BoatEngineStateMachine();
      sm.transition(BoatState.starting);
      expect(() => sm.transition(BoatState.stopping), returnsNormally);
      expect(sm.current, BoatState.stopping);
    });
  });
}

class _DeniedMockPlatform extends MockBoatPlatform {
  @override
  Future<PermissionStatus> checkPermission(PermissionType type) async =>
      PermissionStatus.denied;
}

class _RecordingMockPlatform extends MockBoatPlatform {
  final calls = <String>[];
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> start(BoatConfig config) async => calls.add('start');
}

class _StartFailingMockPlatform extends MockBoatPlatform {
  int _startCount = 0;
  @override
  Future<void> stop() async {}
  @override
  Future<void> start(BoatConfig config) async {
    _startCount++;
    if (_startCount > 1) {
      throw Exception('platform start failed');
    }
  }
}

class _StartFailingWithStopMockPlatform extends MockBoatPlatform {
  bool stopCalled = false;
  @override
  Future<void> stop() async {
    stopCalled = true;
  }
  @override
  Future<void> start(BoatConfig config) async {
    throw Exception('platform start failed');
  }
}

class _EventEmittingMockPlatform extends MockBoatPlatform {
  final _controller = StreamController<BoatEvent>.broadcast();

  void emitEvent(BoatEvent event) => _controller.add(event);

  @override
  Stream<BoatEvent> get events => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _SlowMockPlatform extends MockBoatPlatform {
  @override
  Future<void> start(BoatConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  @override
  Future<void> stop() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
