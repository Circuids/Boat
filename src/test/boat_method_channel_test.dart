import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boat/boat_method_channel.dart';
import 'package:boat/src/common/common.dart';
import 'package:boat/src/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelBoat platform;
  final List<MethodCall> log = [];

  setUp(() {
    platform = MethodChannelBoat();
    log.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannelBoat.methodsChannel,
      (MethodCall call) async {
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
      },
    );
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
    const config = BoatConfig();
    await platform.start(config);

    expect(platform.state, BoatState.running);
    expect(log.single.method, 'start');
    final args = log.single.arguments as Map;
    expect(args['sampleRate'], 16000);
  });

  test('stop invokes native and transitions to idle', () async {
    const config = BoatConfig();
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
    const config = BoatConfig(sampleRate: 48000);
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

  test('play throws UnimplementedError (Phase 4 stub)', () {
    expect(() => platform.play(Uint8List(0)), throwsUnimplementedError);
  });

  group('permissions', () {
    test('checkPermission sends type and parses status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannelBoat.methodsChannel,
        (MethodCall call) async {
          log.add(call);
          if (call.method == 'checkPermission') return 'granted';
          return null;
        },
      );

      final status = await platform.checkPermission(PermissionType.microphone);
      expect(status, PermissionStatus.granted);
      expect(log.single.method, 'checkPermission');
      expect((log.single.arguments as Map)['type'], 'microphone');
    });

    test('requestPermission sends type and parses status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannelBoat.methodsChannel,
        (MethodCall call) async {
          log.add(call);
          if (call.method == 'requestPermission') return 'permanentlyDenied';
          return null;
        },
      );

      final status =
          await platform.requestPermission(PermissionType.bluetoothConnect);
      expect(status, PermissionStatus.permanentlyDenied);
      expect((log.single.arguments as Map)['type'], 'bluetoothConnect');
    });

    test('openAppSettings invokes native', () async {
      await platform.openAppSettings();
      expect(log.single.method, 'openAppSettings');
    });
  });
}
