import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'boat_media_platform.dart';
import 'events/boat_media_events.dart';
import 'exceptions/boat_media_exceptions.dart';
import 'models/boat_media_config.dart';
import 'models/boat_media_state.dart';
import 'models/boat_media_status.dart';

/// Method-channel implementation of [BoatMediaPlatform].
///
/// Wires Dart ↔ native via two channels, disjoint from the voice channels:
/// - `com.circuids.boat/media` (Dart → Native)
/// - `com.circuids.boat/mediaEvents` (Native → Dart)
class MethodChannelBoatMedia implements BoatMediaPlatform {
  @visibleForTesting
  static const methodsChannel = MethodChannel('com.circuids.boat/media');

  @visibleForTesting
  static const eventsChannel = EventChannel('com.circuids.boat/mediaEvents');

  final StreamController<BoatMediaEvent> _eventsController =
      StreamController<BoatMediaEvent>.broadcast();

  BoatMediaState _state = BoatMediaState.idle;
  StreamSubscription<dynamic>? _eventsSub;

  @override
  BoatMediaState get state => _state;

  @override
  Stream<BoatMediaEvent> get events => _eventsController.stream;

  @override
  Future<void> start(BoatMediaConfig config) async {
    _listenEvents();
    try {
      await methodsChannel.invokeMethod<void>('mediaStart', config.toMap());
      _state = BoatMediaState.loading;
    } catch (e) {
      await _cancelSubs();
      _state = BoatMediaState.error;
      throw _mapError(e);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await methodsChannel.invokeMethod<void>('mediaStop');
      _state = BoatMediaState.idle;
    } catch (e) {
      _state = BoatMediaState.error;
      await _cancelSubs();
      throw _mapError(e);
    }
    await _cancelSubs();
  }

  @override
  Future<void> playPcm(Uint8List pcm) => _invoke('mediaPlayPcm', {'pcm': pcm});

  @override
  Future<void> playFile(String path, {bool loop = false}) =>
      _invoke('mediaPlayFile', {'path': path, 'loop': loop});

  @override
  Future<void> playAsset(String assetKey, {bool loop = false}) =>
      _invoke('mediaPlayAsset', {'assetKey': assetKey, 'loop': loop});

  @override
  Future<void> pause() => _invoke('mediaPause');

  @override
  Future<void> resume() => _invoke('mediaResume');

  @override
  Future<void> seek(Duration position) =>
      _invoke('mediaSeek', {'positionMs': position.inMilliseconds});

  @override
  Future<void> setVolume(double volume) =>
      _invoke('mediaSetVolume', {'volume': volume});

  @override
  Future<void> flush() => _invoke('mediaFlush');

  @override
  Future<BoatMediaStatus> get status async {
    try {
      final result = await methodsChannel.invokeMethod<Map<dynamic, dynamic>>(
        'mediaGetStatus',
      );
      return BoatMediaStatus.fromMap(Map<String, dynamic>.from(result ?? {}));
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ── Private helpers ──

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await methodsChannel.invokeMethod<void>(method, args);
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// Maps a native error code to the matching typed exception.
  ///
  /// Unknown codes fall back to [BoatMediaException] so a new native code never
  /// surfaces as a raw [PlatformException].
  BoatMediaException _mapError(Object error) {
    if (error is BoatMediaException) return error;
    if (error is! PlatformException) {
      return BoatMediaException(error.toString());
    }
    final message = error.message ?? error.code;
    return switch (error.code) {
      'MEDIA_BUSY' => BoatMediaBusyException(message, code: error.code),
      'MEDIA_FORMAT_MISMATCH' => BoatMediaFormatException(
        message,
        code: error.code,
      ),
      'MEDIA_INVALID_STATE' => BoatMediaStateException(
        message,
        code: error.code,
      ),
      _ => BoatMediaException(message, code: error.code),
    };
  }

  Future<void> _cancelSubs() async {
    await _eventsSub?.cancel();
    _eventsSub = null;
  }

  void _listenEvents() {
    _eventsSub ??= eventsChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final parsed = _parseEvent(event);
        if (parsed != null) _eventsController.add(parsed);
      },
      onError: (Object error) {
        _state = BoatMediaState.error;
        _eventsController.add(
          BoatMediaError(
            timestamp: DateTime.now(),
            code: 'MEDIA_EVENT_STREAM_ERROR',
            message: error.toString(),
          ),
        );
      },
      onDone: () {
        _eventsSub = null;
      },
    );
  }

  /// Parses a native event map into a [BoatMediaEvent].
  ///
  /// Malformed events emit a [BoatMediaWarning] (code `PARSE_ERROR`) instead of
  /// crashing the stream — one bad event must not kill it.
  BoatMediaEvent? _parseEvent(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type'] as String?;
    final ts = DateTime.now();

    try {
      return switch (type) {
        'mediaStateChanged' => () {
          final event = BoatMediaStateChanged(
            timestamp: ts,
            previous: _stateFromString(map['previous'] as String?),
            current: _stateFromString(map['current'] as String?),
          );
          // Keep the getter in sync with native-driven transitions.
          _state = event.current;
          return event;
        }(),
        'mediaProgress' => BoatMediaProgress(
          timestamp: ts,
          position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
          duration: _durationOrNull(map['durationMs'] as int?),
        ),
        'mediaCompleted' => BoatMediaCompleted(timestamp: ts),
        'mediaWarning' => BoatMediaWarning(
          timestamp: ts,
          code: map['code'] as String? ?? 'unknown',
          message: map['message'] as String? ?? '',
        ),
        'mediaError' => () {
          _state = BoatMediaState.error;
          return BoatMediaError(
            timestamp: ts,
            code: map['code'] as String? ?? 'unknown',
            message: map['message'] as String? ?? '',
          );
        }(),
        'mediaPreempted' => () {
          _state = BoatMediaState.idle;
          return BoatMediaPreempted(
            timestamp: ts,
            reason: map['reason'] as String? ?? 'unknown',
          );
        }(),
        _ => null,
      };
    } catch (_) {
      return BoatMediaWarning(
        timestamp: ts,
        code: 'PARSE_ERROR',
        message: 'Malformed media event: $raw',
      );
    }
  }

  static Duration? _durationOrNull(int? ms) =>
      ms == null || ms < 0 ? null : Duration(milliseconds: ms);

  static BoatMediaState _stateFromString(String? value) {
    for (final state in BoatMediaState.values) {
      if (state.name == value) return state;
    }
    return BoatMediaState.idle;
  }
}
