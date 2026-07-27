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
      _state = BoatState.error;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _state = BoatState.stopping;
    await methodsChannel.invokeMethod<void>('stop');
    _state = BoatState.idle;
    await _captureSub?.cancel();
    _captureSub = null;
  }

  @override
  Future<void> pause() => methodsChannel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => methodsChannel.invokeMethod<void>('resume');

  @override
  Future<void> dispose() async {
    await methodsChannel.invokeMethod<void>('dispose');
    _state = BoatState.disposed;
    await _eventsSub?.cancel();
    await _captureSub?.cancel();
    _eventsSub = null;
    _captureSub = null;
    await _eventsController.close();
    await _captureController.close();
  }

  @override
  Future<void> reconfigure(BoatConfig config) =>
      methodsChannel.invokeMethod<void>('reconfigure', config.toMap());

  @override
  void play(Uint8List pcm) {
    // Wired in Phase 4 when native playback sink is ready.
    throw UnimplementedError('play() not yet wired to native');
  }

  @override
  Future<void> flushPlayback() =>
      methodsChannel.invokeMethod<void>('flushPlayback');

  @override
  Future<void> setRoute(AudioRoute route) async {
    await methodsChannel.invokeMethod<void>(
      'setRoute',
      {'route': route.toChannelString()},
    );
    _currentRoute = route;
  }

  @override
  Future<BoatDiagnostics> getDiagnostics() async {
    final result = await methodsChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getDiagnostics',
    );
    return BoatDiagnostics.fromMap(
      Map<String, dynamic>.from(result ?? {}),
    );
  }

  // ── Private helpers ──

  void _listenEvents() {
    _eventsSub ??= eventsChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final parsed = _parseEvent(event);
        if (parsed != null) _eventsController.add(parsed);
      },
      onError: (Object error) {
        _eventsController.add(BoatError(
          timestamp: DateTime.now(),
          exception: BoatNativeException(error.toString()),
        ));
      },
    );
  }

  void _listenCapture() {
    _captureSub ??= captureChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        final frame = _deserializeFrame(data);
        if (frame != null) _captureController.add(frame);
      },
    );
  }

  BoatEvent? _parseEvent(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type'] as String?;
    final ts = DateTime.now();

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
      'routeChanged' => BoatRouteChanged(
          timestamp: ts,
          previous: AudioRoute.fromString(map['previous'] as String),
          current: AudioRoute.fromString(map['current'] as String),
        ),
      'effectStatusChanged' => BoatEffectStatusChanged(
          timestamp: ts,
          effect: AudioEffectType.values.byName(map['effect'] as String),
          available: map['available'] as bool? ?? false,
          active: map['active'] as bool? ?? false,
        ),
      _ => null,
    };
  }

  /// Deserializes a capture frame from platform channel bytes.
  ///
  /// Wire format (little-endian):
  /// [8B seq][8B timestampNanos][4B sampleRate][4B channelCount][pcm...]
  AudioFrame? _deserializeFrame(dynamic data) {
    if (data is! Uint8List || data.length < 24) return null;
    final bd = ByteData.sublistView(data);

    final seq = bd.getInt64(0, Endian.little);
    final tsNanos = bd.getInt64(8, Endian.little);
    final sampleRate = bd.getInt32(16, Endian.little);
    final channelCount = bd.getInt32(20, Endian.little);
    final pcm = Uint8List.sublistView(data, 24);

    return AudioFrame(
      pcm: pcm,
      sequenceNumber: seq,
      timestamp: Duration(microseconds: tsNanos ~/ 1000),
      sampleRate: sampleRate,
      channelCount: channelCount,
    );
  }
}
