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
///
/// Lifecycle methods ([start], [stop], [pause], [resume], [dispose],
/// [reconfigure]) are serialized via a [Completer]-based mutex so
/// overlapping calls do not race the state machine.
class BoatEngine {
  final BoatPlatform _platform;
  final BoatEngineStateMachine _sm = BoatEngineStateMachine();

  StreamSubscription<BoatEvent>? _eventSub;
  final StreamController<BoatEvent> _eventController =
      StreamController<BoatEvent>.broadcast();

  // ── Concurrency mutex ──
  //
  // If non-null, a lifecycle operation is in progress. The second caller
  // awaits this completer before proceeding. This prevents overlapping
  // start/stop/dispose from racing the state machine.
  Completer<void>? _lifecycleLock;

  BoatEngine({BoatPlatform? platform})
    : _platform = platform ?? BoatPlatform.instance {
    _eventSub = _platform.events.listen(
      _handleEvent,
      onError: (Object error) {
        // Stream-level error (not a BoatError event) — force the state
        // machine to error so consumers see the failure.
        if (_sm.current != BoatState.disposed &&
            _sm.current != BoatState.error) {
          _sm.transition(BoatState.error);
        }
      },
    );
  }

  /// Forwards events to consumers and reconciles the state machine when
  /// native reports a fatal [BoatError].
  void _handleEvent(BoatEvent event) {
    if (event is BoatError &&
        _sm.current != BoatState.disposed &&
        _sm.current != BoatState.error) {
      _sm.transition(BoatState.error);
    }
    _eventController.add(event);
  }

  /// Acquires the lifecycle mutex. If another lifecycle call is in
  /// progress, awaits its completion before proceeding.
  Future<void> _acquireLock() async {
    while (_lifecycleLock != null) {
      try {
        await _lifecycleLock!.future;
      } catch (_) {
        // Previous operation failed — we can still proceed with ours.
      }
    }
    _lifecycleLock = Completer<void>();
  }

  void _releaseLock() {
    final lock = _lifecycleLock;
    _lifecycleLock = null;
    lock?.complete();
  }

  // ── Lifecycle ──

  BoatState get state => _sm.current;

  Stream<BoatEvent> get events => _eventController.stream;

  Future<void> start([BoatConfig? config]) async {
    await _acquireLock();
    try {
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
        await _platform.start(config ?? BoatConfig());
        _sm.transition(BoatState.running);
      } catch (e) {
        // Clean up partially-started native engine before erroring.
        try {
          await _platform.stop();
        } catch (_) {
          // Best-effort — the original error is what matters.
        }
        _sm.transition(BoatState.error);
        rethrow;
      }
    } finally {
      _releaseLock();
    }
  }

  Future<void> stop() async {
    await _acquireLock();
    try {
      _sm.transition(BoatState.stopping);
      try {
        await _platform.stop();
        _sm.transition(BoatState.idle);
      } catch (e) {
        _sm.transition(BoatState.error);
        rethrow;
      }
    } finally {
      _releaseLock();
    }
  }

  Future<void> pause() async {
    await _acquireLock();
    try {
      // Transition after a successful platform call — on failure, go to
      // error instead of falsely claiming paused.
      try {
        await _platform.pause();
        _sm.transition(BoatState.paused);
      } catch (e) {
        if (_sm.current != BoatState.error) {
          _sm.transition(BoatState.error);
        }
        rethrow;
      }
    } finally {
      _releaseLock();
    }
  }

  Future<void> resume() async {
    await _acquireLock();
    try {
      try {
        await _platform.resume();
        _sm.transition(BoatState.running);
      } catch (e) {
        if (_sm.current != BoatState.error) {
          _sm.transition(BoatState.error);
        }
        rethrow;
      }
    } finally {
      _releaseLock();
    }
  }

  /// Terminal — engine cannot be restarted after this.
  Future<void> dispose() async {
    await _acquireLock();
    try {
      try {
        await _platform.dispose();
      } catch (e) {
        // Still release Dart-side resources even if native dispose fails,
        // but do not transition to disposed since native state is unknown.
        await _eventSub?.cancel();
        _eventSub = null;
        await _eventController.close();
        rethrow;
      }
      _sm.transition(BoatState.disposed);
      await _eventSub?.cancel();
      _eventSub = null;
      await _eventController.close();
    } finally {
      _releaseLock();
    }
  }

  // ── Capture ──

  Stream<AudioFrame> get captureFrames => _platform.captureFrames;

  // ── Playback ──

  void play(AudioFrame frame) {
    _ensurePlaybackReady();
    _platform.play(frame.pcm);
  }

  void playRaw(Uint8List pcm) {
    _ensurePlaybackReady();
    _platform.play(pcm);
  }

  /// Playback is only valid while the engine is actively running or paused
  /// (paused engines still hold the playback node). Throws [StateError]
  /// otherwise so callers fail fast instead of silently dropping audio.
  void _ensurePlaybackReady() {
    final s = _sm.current;
    if (s != BoatState.running && s != BoatState.paused) {
      throw StateError(
        'play() requires engine state running or paused, was $s',
      );
    }
  }

  Future<void> flushPlayback() => _platform.flushPlayback();

  // ── Configuration ──

  Future<void> reconfigure(BoatConfig config) async {
    await _acquireLock();
    try {
      _sm.transition(BoatState.stopping);
      try {
        await _platform.stop();
      } catch (e) {
        _sm.transition(BoatState.error);
        rethrow;
      }
      _sm.transition(BoatState.idle);
      _sm.transition(BoatState.starting);
      try {
        await _platform.start(config);
        _sm.transition(BoatState.running);
      } catch (e) {
        // Clean up partially-started native engine before erroring.
        try {
          await _platform.stop();
        } catch (_) {}
        _sm.transition(BoatState.error);
        rethrow;
      }
    } finally {
      _releaseLock();
    }
  }

  // ── Routing ──

  AudioRoute get currentRoute => _platform.currentRoute;

  Future<void> setRoute(AudioRoute route) => _platform.setRoute(route);

  // ── Diagnostics ──

  Future<BoatDiagnostics> get diagnostics => _platform.getDiagnostics();
}
