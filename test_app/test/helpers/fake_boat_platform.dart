import 'dart:async';
import 'dart:typed_data';

import 'package:boat/boat.dart';

/// In-process fake of [BoatPlatform] for unit tests — no native channels.
class FakeBoatPlatform extends BoatPlatform {
  BoatState _state = BoatState.idle;
  final _eventsController = StreamController<BoatEvent>.broadcast();
  final _captureController = StreamController<AudioFrame>.broadcast();

  List<Uint8List> played = [];
  List<BoatConfig> startedConfigs = [];
  int flushCount = 0;
  AudioRoute route = AudioRoute.speaker;
  PermissionStatus micPermission = PermissionStatus.granted;

  @override
  BoatState get state => _state;

  @override
  Stream<BoatEvent> get events => _eventsController.stream;

  @override
  Stream<AudioFrame> get captureFrames => _captureController.stream;

  @override
  void play(Uint8List pcm) => played.add(pcm);

  @override
  Future<void> flushPlayback() async => flushCount++;

  @override
  AudioRoute get currentRoute => route;

  @override
  Future<void> setRoute(AudioRoute r) async => route = r;

  @override
  Future<BoatDiagnostics> getDiagnostics() async => BoatDiagnostics(
        deviceModel: 'FakeDevice',
        osVersion: 'test',
        audioSessionId: 1,
        effectStatus: const {
          AudioEffectType.aec: EffectStatus(supported: true, available: true, active: true),
          AudioEffectType.agc: EffectStatus(supported: true, available: true, active: true),
          AudioEffectType.noiseSuppression:
              EffectStatus(supported: true, available: true, active: true),
        },
        currentRoute: route,
        availableRoutes: const [AudioRoute.speaker, AudioRoute.earpiece],
        captureFrameCount: 0,
        playbackFrameCount: played.length,
        uptime: Duration.zero,
      );

  @override
  Future<PermissionStatus> checkPermission(PermissionType type) async =>
      micPermission;

  @override
  Future<PermissionStatus> requestPermission(PermissionType type) async =>
      micPermission;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> start(BoatConfig config) async {
    startedConfigs.add(config);
    _state = BoatState.running;
    _eventsController.add(BoatStateChanged(
      timestamp: DateTime.now(),
      previous: BoatState.idle,
      current: BoatState.running,
    ));
  }

  @override
  Future<void> stop() async {
    _state = BoatState.idle;
    _eventsController.add(BoatStateChanged(
      timestamp: DateTime.now(),
      previous: BoatState.running,
      current: BoatState.idle,
    ));
  }

  @override
  Future<void> pause() async => _state = BoatState.paused;

  @override
  Future<void> resume() async => _state = BoatState.running;

  @override
  Future<void> dispose() async {
    await _eventsController.close();
    await _captureController.close();
    _state = BoatState.disposed;
  }

  @override
  Future<void> reconfigure(BoatConfig config) async {
    startedConfigs.add(config);
    _state = BoatState.running;
  }

  void emitEvent(BoatEvent e) => _eventsController.add(e);
  void emitFrame(AudioFrame f) => _captureController.add(f);
}