import 'dart:async';
import 'dart:typed_data';

import '../boat_platform_interface.dart';
import 'boat_engine_state_machine.dart';
import 'common/common.dart';
import 'diagnostics/diagnostics.dart';
import 'events/events.dart';
import 'exceptions/exceptions.dart';
import 'models/models.dart';

/// Public entry point for the Boat audio engine.
///
/// Enforces the lifecycle state machine and delegates to [BoatPlatform].
class BoatEngine {
  final BoatPlatform _platform;
  final BoatEngineStateMachine _sm = BoatEngineStateMachine();

  StreamSubscription<BoatEvent>? _eventSub;
  final StreamController<BoatEvent> _eventController =
      StreamController<BoatEvent>.broadcast();

  BoatEngine({BoatPlatform? platform})
      : _platform = platform ?? BoatPlatform.instance {
    _eventSub = _platform.events.listen(_eventController.add);
  }

  // ── Lifecycle ──

  BoatState get state => _sm.current;

  Stream<BoatEvent> get events => _eventController.stream;

  Future<void> start([BoatConfig? config]) async {
    final status = await _platform.checkPermission(PermissionType.microphone);
    if (status != PermissionStatus.granted) {
      throw BoatPermissionException(
        'Microphone permission not granted. '
        'Call BoatPermission.request() before start().',
        code: 'PERMISSION_DENIED',
      );
    }
    _sm.transition(BoatState.starting);
    try {
      await _platform.start(config ?? const BoatConfig());
      _sm.transition(BoatState.running);
    } catch (e) {
      _sm.transition(BoatState.error);
      rethrow;
    }
  }

  Future<void> stop() async {
    _sm.transition(BoatState.stopping);
    await _platform.stop();
    _sm.transition(BoatState.idle);
  }

  Future<void> pause() async {
    _sm.transition(BoatState.paused);
    await _platform.pause();
  }

  Future<void> resume() async {
    _sm.transition(BoatState.running);
    await _platform.resume();
  }

  /// Terminal — engine cannot be restarted after this.
  Future<void> dispose() async {
    _sm.transition(BoatState.disposed);
    await _eventSub?.cancel();
    await _eventController.close();
    await _platform.dispose();
  }

  // ── Capture ──

  Stream<AudioFrame> get captureFrames => _platform.captureFrames;

  // ── Playback ──

  void play(AudioFrame frame) => _platform.play(frame.pcm);

  void playRaw(Uint8List pcm) => _platform.play(pcm);

  Future<void> flushPlayback() => _platform.flushPlayback();

  // ── Configuration ──

  Future<void> reconfigure(BoatConfig config) async {
    _sm.transition(BoatState.stopping);
    await _platform.stop();
    _sm.transition(BoatState.starting);
    await _platform.start(config);
    _sm.transition(BoatState.running);
  }

  // ── Routing ──

  AudioRoute get currentRoute => _platform.currentRoute;

  Future<void> setRoute(AudioRoute route) => _platform.setRoute(route);

  // ── Diagnostics ──

  Future<BoatDiagnostics> get diagnostics => _platform.getDiagnostics();
}
