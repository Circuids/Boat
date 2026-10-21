import 'dart:async';
import 'dart:typed_data';

import 'boat_media_method_channel.dart';
import 'boat_media_platform.dart';
import 'events/boat_media_events.dart';
import 'exceptions/boat_media_exceptions.dart';
import 'models/boat_media_config.dart';
import 'models/boat_media_state.dart';
import 'models/boat_media_status.dart';

/// Standalone audio playback bus for application media.
///
/// Owns its own OS audio session configured for media (Android `USAGE_MEDIA`,
/// iOS `.playback`) and has no relationship to AEC, AGC, noise suppression, the
/// capture pipeline, or the voice playback path.
///
/// Media and voice are **mutually exclusive owners of the audio session**:
/// [start] throws [BoatMediaBusyException] while the voice engine is running,
/// and starting the voice engine preempts media (reported as
/// [BoatMediaPreempted] on [events]).
///
/// This class never touches `BoatEngine` — it is a peer, not a member.
class BoatMediaPlayer {
  final BoatMediaPlatform _platform;

  StreamSubscription<BoatMediaEvent>? _eventSub;
  final StreamController<BoatMediaEvent> _eventController =
      StreamController<BoatMediaEvent>.broadcast();

  // Serializes lifecycle operations so overlapping start/stop/dispose cannot
  // race the state machine. Playback commands are not mutexed — they are cheap
  // channel calls ordered natively by the single media output.
  Completer<void>? _lifecycleLock;

  BoatMediaState _state = BoatMediaState.idle;
  bool _disposed = false;

  /// Whether a file or asset source has established the output format.
  bool _fileFormatEstablished = false;

  BoatMediaPlayer({BoatMediaPlatform? platform})
    : _platform = platform ?? MethodChannelBoatMedia() {
    _eventSub = _platform.events.listen(_handleEvent);
  }

  /// Current media state. Independent of `BoatEngine.state`.
  BoatMediaState get state => _state;

  /// Media events: state changes, progress, completion, warnings, errors, and
  /// preemption.
  Stream<BoatMediaEvent> get events => _eventController.stream;

  // ── Lifecycle ──

  /// Acquires the audio session and creates the media output.
  ///
  /// Throws [BoatMediaBusyException] when the voice engine owns the session.
  /// Idempotent while already started.
  Future<void> start([BoatMediaConfig? config]) async {
    _ensureNotDisposed();
    await _acquireLock();
    try {
      if (_state == BoatMediaState.loading ||
          _state == BoatMediaState.playing ||
          _state == BoatMediaState.paused ||
          _state == BoatMediaState.completed) {
        return;
      }
      await _platform.start(config ?? BoatMediaConfig());
      _setState(BoatMediaState.loading);
    } catch (e) {
      // A refused or failed start leaves no usable session; reflect that in the
      // player's own state rather than reporting idle.
      _setState(BoatMediaState.error);
      rethrow;
    } finally {
      _releaseLock();
    }
  }

  /// Releases the media session and the arbiter. Reversible — [start] may be
  /// called again.
  Future<void> stop() async {
    _ensureNotDisposed();
    await _acquireLock();
    try {
      await _platform.stop();
      _fileFormatEstablished = false;
      _setState(BoatMediaState.idle);
    } finally {
      _releaseLock();
    }
  }

  /// Terminal. Releases everything and closes [events].
  ///
  /// Idempotent — a second call is a no-op. Every other method throws
  /// [BoatMediaStateException] afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    await _acquireLock();
    try {
      if (_disposed) return;
      try {
        await _platform.stop();
      } catch (_) {
        // Best-effort: the player is terminal either way.
      }
      _disposed = true;
      _state = BoatMediaState.idle;
      await _eventSub?.cancel();
      _eventSub = null;
      await _eventController.close();
    } finally {
      _releaseLock();
    }
  }

  // ── Playback ──

  /// Plays streaming PCM. Format must match [BoatMediaConfig] unless a file
  /// source has already established the output format.
  Future<void> playPcm(Uint8List pcm) async {
    _ensurePlayable();
    await _platform.playPcm(pcm);
    _setState(BoatMediaState.playing);
  }

  /// Plays a WAV file. Replaces the active source if one is playing.
  Future<void> playFile(String path, {bool loop = false}) async {
    _ensurePlayable();
    await _platform.playFile(path, loop: loop);
    _fileFormatEstablished = true;
    _setState(BoatMediaState.playing);
  }

  /// Plays a WAV asset bundled with the app. Replaces the active source if one
  /// is playing.
  Future<void> playAsset(String assetKey, {bool loop = false}) async {
    _ensurePlayable();
    await _platform.playAsset(assetKey, loop: loop);
    _fileFormatEstablished = true;
    _setState(BoatMediaState.playing);
  }

  Future<void> pause() async {
    _ensurePlayable();
    await _platform.pause();
    _setState(BoatMediaState.paused);
  }

  Future<void> resume() async {
    _ensurePlayable();
    await _platform.resume();
    _setState(BoatMediaState.playing);
  }

  /// Seeks within a file or asset source.
  ///
  /// Throws [BoatMediaStateException] for streaming PCM — a PCM stream has no
  /// seekable timeline.
  Future<void> seek(Duration position) async {
    _ensurePlayable();
    if (!_fileFormatEstablished) {
      throw const BoatMediaStateException(
        'seek() requires a file or asset source; streaming PCM is not seekable',
        code: 'MEDIA_INVALID_STATE',
      );
    }
    await _platform.seek(position);
  }

  Future<void> setVolume(double volume) async {
    _ensurePlayable();
    await _platform.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Discards buffered PCM. Position is retained.
  Future<void> flush() async {
    _ensurePlayable();
    await _platform.flush();
  }

  /// Snapshot of playback state.
  Future<BoatMediaStatus> get status async {
    _ensureNotDisposed();
    return _platform.status;
  }

  // ── Private helpers ──

  void _handleEvent(BoatMediaEvent event) {
    if (event is BoatMediaStateChanged) {
      _state = event.current;
    } else if (event is BoatMediaPreempted) {
      _state = BoatMediaState.idle;
      _fileFormatEstablished = false;
    } else if (event is BoatMediaError) {
      _state = BoatMediaState.error;
    } else if (event is BoatMediaCompleted) {
      _state = BoatMediaState.completed;
    }
    if (!_eventController.isClosed) _eventController.add(event);
  }

  void _setState(BoatMediaState next) {
    if (_state == next) return;
    final previous = _state;
    _state = next;
    if (!_eventController.isClosed) {
      _eventController.add(
        BoatMediaStateChanged(
          timestamp: DateTime.now(),
          previous: previous,
          current: next,
        ),
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const BoatMediaStateException(
        'BoatMediaPlayer has been disposed',
        code: 'MEDIA_INVALID_STATE',
      );
    }
  }

  /// Playback requires a started bus. `start()` already refused if the voice
  /// engine held the session, so reaching here means media owns it.
  void _ensurePlayable() {
    _ensureNotDisposed();
    if (_state == BoatMediaState.idle || _state == BoatMediaState.error) {
      throw BoatMediaStateException(
        'playback requires a started media bus, was $_state',
        code: 'MEDIA_INVALID_STATE',
      );
    }
  }

  Future<void> _acquireLock() async {
    while (_lifecycleLock != null) {
      try {
        await _lifecycleLock!.future;
      } catch (_) {
        // Previous operation failed — proceed with ours.
      }
    }
    _lifecycleLock = Completer<void>();
  }

  void _releaseLock() {
    final lock = _lifecycleLock;
    _lifecycleLock = null;
    lock?.complete();
  }
}
