import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boat/boat_method_channel.dart';
import 'package:boat/src/common/common.dart';
import 'package:boat/src/events/events.dart';
import 'package:boat/src/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelBoat platform;
  final List<MethodCall> log = [];

  setUp(() {
    platform = MethodChannelBoat();
    log.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
          MethodCall call,
        ) async {
          log.add(call);
          return switch (call.method) {
            'getDiagnostics' => <String, dynamic>{
              'deviceModel': 'test',
              'osVersion': '1',
              'audioSessionId': 1,
              'effectStatus': <String, dynamic>{},
              'currentRoute': 'speaker',
              'availableRoutes': <String>['speaker'],
              'captureFrameCount': 0,
              'playbackFrameCount': 0,
              'uptimeMs': 0,
            },
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, null);
  });

  test('initial state is idle', () {
    expect(platform.state, BoatState.idle);
    expect(platform.currentRoute, AudioRoute.speaker);
  });

  test('start invokes native and transitions to running', () async {
    final config = BoatConfig();
    await platform.start(config);

    expect(platform.state, BoatState.running);
    expect(log.single.method, 'start');
    final args = log.single.arguments as Map;
    expect(args['sampleRate'], 16000);
  });

  test('stop invokes native and transitions to idle', () async {
    final config = BoatConfig();
    await platform.start(config);
    await platform.stop();

    expect(platform.state, BoatState.idle);
    expect(log.map((c) => c.method), ['start', 'stop']);
  });

  test('pause and resume invoke native', () async {
    await platform.pause();
    await platform.resume();
    expect(log.map((c) => c.method), ['pause', 'resume']);
  });

  test('dispose invokes native and sets disposed state', () async {
    await platform.dispose();
    expect(platform.state, BoatState.disposed);
    expect(log.single.method, 'dispose');
  });

  test('reconfigure sends config map', () async {
    final config = BoatConfig(sampleRate: 48000);
    await platform.reconfigure(config);

    expect(log.single.method, 'reconfigure');
    expect((log.single.arguments as Map)['sampleRate'], 48000);
  });

  test('setRoute updates currentRoute', () async {
    await platform.setRoute(AudioRoute.bluetooth);
    expect(platform.currentRoute, AudioRoute.bluetooth);
    expect(log.single.method, 'setRoute');
    expect((log.single.arguments as Map)['route'], 'bluetooth');
  });

  test('flushPlayback invokes native', () async {
    await platform.flushPlayback();
    expect(log.single.method, 'flushPlayback');
  });

  test('getDiagnostics parses response', () async {
    final diag = await platform.getDiagnostics();
    expect(diag.deviceModel, 'test');
    expect(diag.currentRoute, AudioRoute.speaker);
  });

  test('play sends pcm via method channel', () {
    platform.play(Uint8List.fromList([1, 2, 3, 4]));
    expect(log.single.method, 'play');
    expect(
      (log.single.arguments as Map)['pcm'],
      Uint8List.fromList([1, 2, 3, 4]),
    );
  });

  group('permissions', () {
    test('checkPermission sends type and parses status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            log.add(call);
            if (call.method == 'checkPermission') return 'granted';
            return null;
          });

      final status = await platform.checkPermission(PermissionType.microphone);
      expect(status, PermissionStatus.granted);
      expect(log.single.method, 'checkPermission');
      expect((log.single.arguments as Map)['type'], 'microphone');
    });

    test('requestPermission sends type and parses status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            log.add(call);
            if (call.method == 'requestPermission') return 'permanentlyDenied';
            return null;
          });

      final status = await platform.requestPermission(
        PermissionType.bluetoothConnect,
      );
      expect(status, PermissionStatus.permanentlyDenied);
      expect((log.single.arguments as Map)['type'], 'bluetoothConnect');
    });

    test('openAppSettings invokes native', () async {
      await platform.openAppSettings();
      expect(log.single.method, 'openAppSettings');
    });
  });

  // ── Production hardening tests ──

  group('start failure cleanup', () {
    test('start cleans up subscriptions on failure', () async {
      // Make the native start call throw.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            log.add(call);
            if (call.method == 'start') {
              throw PlatformException(code: 'START_FAILED');
            }
            return null;
          });

      final config = BoatConfig();
      await expectLater(
        platform.start(config),
        throwsA(isA<PlatformException>()),
      );
      expect(platform.state, BoatState.error);
    });
  });

  group('stop failure handling', () {
    test('stop transitions to error on native failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            log.add(call);
            if (call.method == 'stop') {
              throw PlatformException(code: 'STOP_FAILED');
            }
            return null;
          });

      await expectLater(platform.stop(), throwsA(isA<PlatformException>()));
      expect(platform.state, BoatState.error);
    });
  });

  group('dispose always closes controllers', () {
    test('dispose closes controllers even if native throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            if (call.method == 'dispose') {
              throw PlatformException(code: 'DISPOSE_FAILED');
            }
            return null;
          });

      await expectLater(platform.dispose(), throwsA(isA<PlatformException>()));
      // State should NOT be disposed since native failed.
      expect(platform.state, isNot(BoatState.disposed));
    });
  });

  group('play error surfacing', () {
    test('play surfaces error as BoatWarning via events stream', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            log.add(call);
            if (call.method == 'play') {
              throw PlatformException(code: 'PLAYBACK_ERROR');
            }
            return null;
          });

      final receivedEvents = <BoatEvent>[];
      platform.events.listen(receivedEvents.add);

      platform.play(Uint8List.fromList([1, 2, 3, 4]));

      // Give the catchError callback time to fire.
      await Future<void>.delayed(Duration.zero);

      expect(log.any((c) => c.method == 'play'), isTrue);
      expect(receivedEvents, isNotEmpty);
      expect(receivedEvents.any((e) => e is BoatWarning), isTrue);
    });
  });

  group('setRoute error handling', () {
    test('setRoute does not update currentRoute on native failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            if (call.method == 'setRoute') {
              throw PlatformException(code: 'ROUTE_FAILED');
            }
            return null;
          });

      expect(platform.currentRoute, AudioRoute.speaker);
      await expectLater(
        platform.setRoute(AudioRoute.bluetooth),
        throwsA(isA<PlatformException>()),
      );
      // Route should NOT have changed.
      expect(platform.currentRoute, AudioRoute.speaker);
    });
  });

  group('getDiagnostics error handling', () {
    test('returns safe defaults on native failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelBoat.methodsChannel, (
            MethodCall call,
          ) async {
            if (call.method == 'getDiagnostics') {
              throw PlatformException(code: 'DIAG_FAILED');
            }
            return null;
          });

      final diag = await platform.getDiagnostics();
      expect(diag.deviceModel, '');
      expect(diag.audioSessionId, -1);
    });
  });
}
