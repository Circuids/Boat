import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'boat_platform_interface.dart';
import 'src/common/common.dart';
import 'src/diagnostics/diagnostics.dart';
import 'src/events/events.dart';
import 'src/exceptions/exceptions.dart';
import 'src/models/models.dart';

/// Method-channel implementation of [BoatPlatform].
///
/// Wires Dart ↔ native via four channels:
/// - `com.circuids.boat/methods` (Dart → Native)
/// - `com.circuids.boat/events` (Native → Dart)
/// - `com.circuids.boat/capture` (Native → Dart)
/// - `com.circuids.boat/playback` (Dart → Native)
class MethodChannelBoat extends BoatPlatform {
  @visibleForTesting
  static const methodsChannel = MethodChannel('com.circuids.boat/methods');

  @visibleForTesting
  static const eventsChannel = EventChannel('com.circuids.boat/events');

  @visibleForTesting
  static const captureChannel = EventChannel('com.circuids.boat/capture');

  @visibleForTesting
  static const playbackChannel = EventChannel('com.circuids.boat/playback');

  final StreamController<BoatEvent> _eventsController =
      StreamController<BoatEvent>.broadcast();
  final StreamController<AudioFrame> _captureController =
      StreamController<AudioFrame>.broadcast();

  BoatState _state = BoatState.idle;
  AudioRoute _currentRoute = AudioRoute.speaker;
  StreamSubscription<dynamic>? _eventsSub;
  StreamSubscription<dynamic>? _captureSub;

  @override
  BoatState get state => _state;

  @override
  Stream<BoatEvent> get events => _eventsController.stream;

  @override
  Stream<AudioFrame> get captureFrames => _captureController.stream;

  @override
  AudioRoute get currentRoute => _currentRoute;

  @override
  Future<void> start(BoatConfig config) async {
    _state = BoatState.starting;
    _listenEvents();
    _listenCapture();
    try {
      await methodsChannel.invokeMethod<void>('start', config.toMap());
      _state = BoatState.running;
    } catch (e) {
      // Clean up subscriptions before rethrowing — native never started
      // successfully, so the event streams are dead weight.
      await _cancelSubs();
      _state = BoatState.error;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _state = BoatState.stopping;
    try {
      await methodsChannel.invokeMethod<void>('stop');
      _state = BoatState.idle;
    } catch (e) {
      _state = BoatState.error;
      // Still cancel subs — native may be in an unknown state, but the
      // Dart-side streams should not keep delivering into a dead engine.
      await _cancelSubs();
      rethrow;
    }
    await _cancelSubs();
  }

  @override
  Future<void> pause() => methodsChannel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => methodsChannel.invokeMethod<void>('resume');

  @override
  Future<void> dispose() async {
    try {
      await methodsChannel.invokeMethod<void>('dispose');
    } catch (_) {
      // Dispose is best-effort on the native side — always release Dart
      // resources even if native throws. Do not transition to disposed
      // since native state is unknown.
      await _cancelSubs();
      await _closeControllers();
      rethrow;
    }
    _state = BoatState.disposed;
    await _cancelSubs();
    await _closeControllers();
  }

  @override
  Future<void> reconfigure(BoatConfig config) =>
      methodsChannel.invokeMethod<void>('reconfigure', config.toMap());

  @override
  void play(Uint8List pcm) {
    methodsChannel
        .invokeMethod<void>('play', {'pcm': pcm})
        .catchError((Object error) {
          // play() is void by API contract — surface failures as warnings
          // so consumers learn the playback dropped without changing the
          // signature (which would be a breaking change).
          _eventsController.add(BoatWarning(
            timestamp: DateTime.now(),
            code: 'PLAYBACK_FAILED',
            message: error.toString(),
          ));
        });
  }

  @override
  Future<void> flushPlayback() =>
      methodsChannel.invokeMethod<void>('flushPlayback');

  @override
  Future<void> setRoute(AudioRoute route) async {
    try {
      await methodsChannel.invokeMethod<void>(
        'setRoute',
        {'route': route.toChannelString()},
      );
      _currentRoute = route;
    } catch (_) {
      // Do not update _currentRoute if native rejected the route.
      rethrow;
    }
  }

  @override
  Future<BoatDiagnostics> getDiagnostics() async {
    try {
      final result = await methodsChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getDiagnostics',
      );
      return BoatDiagnostics.fromMap(
        Map<String, dynamic>.from(result ?? {}),
      );
    } catch (_) {
      // Return a minimal diagnostics snapshot rather than crashing when
      // native is unavailable (e.g. engine disposed mid-query).
      return const BoatDiagnostics(
        deviceModel: '',
        osVersion: '',
        audioSessionId: -1,
        effectStatus: {},
        currentRoute: AudioRoute.speaker,
        availableRoutes: [],
        captureFrameCount: 0,
        playbackFrameCount: 0,
        uptime: Duration.zero,
      );
    }
  }

  @override
  Future<PermissionStatus> checkPermission(PermissionType type) async {
    try {
      final result = await methodsChannel.invokeMethod<String>(
        'checkPermission',
        {'type': type.toChannelString()},
      );
      return PermissionStatus.fromString(result ?? 'denied');
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  @override
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    try {
      final result = await methodsChannel.invokeMethod<String>(
        'requestPermission',
        {'type': type.toChannelString()},
      );
      return PermissionStatus.fromString(result ?? 'denied');
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  @override
  Future<void> openAppSettings() =>
      methodsChannel.invokeMethod<void>('openAppSettings');

  // ── Private helpers ──

  Future<void> _cancelSubs() async {
    await _eventsSub?.cancel();
    await _captureSub?.cancel();
    _eventsSub = null;
    _captureSub = null;
  }

  Future<void> _closeControllers() async {
    await _eventsController.close();
    await _captureController.close();
  }

  void _listenEvents() {
    _eventsSub ??= eventsChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final parsed = _parseEvent(event);
        if (parsed != null) _eventsController.add(parsed);
      },
      onError: (Object error) {
        _state = BoatState.error;
        _eventsController.add(BoatError(
          timestamp: DateTime.now(),
          exception: BoatNativeException(error.toString()),
        ));
      },
      onDone: () {
        _eventsSub = null;
      },
    );
  }

  void _listenCapture() {
    _captureSub ??= captureChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        final frame = _deserializeFrame(data);
        if (frame != null) _captureController.add(frame);
      },
      onError: (Object error) {
        _eventsController.add(BoatError(
          timestamp: DateTime.now(),
          exception: BoatNativeException(
            'Capture stream error: $error',
            code: 'CAPTURE_STREAM_ERROR',
          ),
        ));
      },
      onDone: () {
        _captureSub = null;
      },
    );
  }

  /// Parses a native event map into a [BoatEvent].
  ///
  /// Malformed events emit a [BoatWarning] (code `PARSE_ERROR`) instead of
  /// crashing the event stream — one bad event must not kill the stream.
  /// Native `'error'` events are parsed into [BoatError] and forwarded.
  BoatEvent? _parseEvent(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type'] as String?;
    final ts = DateTime.now();

    try {
      return switch (type) {
        'stateChanged' => BoatStateChanged(
            timestamp: ts,
            previous: BoatState.values.byName(map['previous'] as String),
            current: BoatState.values.byName(map['current'] as String),
          ),
        'warning' => BoatWarning(
            timestamp: ts,
            code: map['code'] as String? ?? 'unknown',
            message: map['message'] as String? ?? '',
          ),
        'routeChanged' => () {
            final event = BoatRouteChanged(
              timestamp: ts,
              previous: AudioRoute.fromString(map['previous'] as String),
              current: AudioRoute.fromString(map['current'] as String),
            );
            // Side-effect: keep the getter in sync with externally-driven
            // route changes (headset plug/unplug, Bluetooth connect).
            _currentRoute = event.current;
            return event;
          }(),
        'effectStatusChanged' => BoatEffectStatusChanged(
            timestamp: ts,
            effect: AudioEffectType.values.byName(map['effect'] as String),
            available: map['available'] as bool? ?? false,
            active: map['active'] as bool? ?? false,
          ),
        'error' => BoatError(
            timestamp: ts,
            exception: BoatNativeException(
              map['message'] as String? ?? 'Unknown native error',
              code: map['code'] as String?,
            ),
          ),
        _ => null,
      };
    } catch (e) {
      return BoatWarning(
        timestamp: ts,
        code: 'PARSE_ERROR',
        message: 'Failed to parse event: $e',
      );
    }
  }

  /// Deserializes a capture frame from platform channel bytes.
  ///
  /// Wire format (little-endian):
  /// [8B seq][8B timestampNanos][4B sampleRate][4B channelCount][pcm...]
  ///
  /// PCM is **copied** out of the platform buffer — the platform channel
  /// may recycle the underlying bytes after this callback returns, so a
  /// view (`sublistView`) would be corrupted by the time the consumer
  /// reads it.
  AudioFrame? _deserializeFrame(dynamic data) {
    if (data is! Uint8List || data.length < 24) return null;
    final bd = ByteData.sublistView(data);

    final seq = bd.getInt64(0, Endian.little);
    final tsNanos = bd.getInt64(8, Endian.little);
    final sampleRate = bd.getInt32(16, Endian.little);
    final channelCount = bd.getInt32(20, Endian.little);
    final pcm = Uint8List.fromList(data.sublist(24));

    return AudioFrame(
      pcm: pcm,
      sequenceNumber: seq,
      timestamp: Duration(microseconds: tsNanos ~/ 1000),
      sampleRate: sampleRate,
      channelCount: channelCount,
    );
  }
}
