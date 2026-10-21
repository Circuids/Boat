import 'dart:async';

import 'package:boat/boat_media.dart';
import 'package:fairy/fairy.dart';

import '../services/media_service.dart';

/// Drives the media screen: playback commands, live position, and preemption.
class MediaViewModel extends ObservableObject {
  final MediaService _service;

  final state = ObservableProperty<BoatMediaState>(BoatMediaState.idle);
  final positionMs = ObservableProperty<int>(0);
  final durationMs = ObservableProperty<int>(-1);
  final volume = ObservableProperty<double>(1.0);
  final sourceKind = ObservableProperty<BoatMediaSourceKind>(
    BoatMediaSourceKind.none,
  );
  final isLooping = ObservableProperty<bool>(false);
  final lastError = ObservableProperty<String?>(null);
  final preemptionReason = ObservableProperty<String?>(null);
  final log = ObservableProperty<List<String>>(<String>[]);

  StreamSubscription<BoatMediaEvent>? _sub;

  MediaViewModel(this._service) {
    _sub = _service.player.events.listen(_onEvent);
  }

  BoatMediaPlayer get player => _service.player;

  void _onEvent(BoatMediaEvent event) {
    switch (event) {
      case BoatMediaStateChanged(:final current):
        state.value = current;
      case BoatMediaProgress(:final position, :final duration):
        positionMs.value = position.inMilliseconds;
        durationMs.value = duration?.inMilliseconds ?? -1;
      case BoatMediaCompleted():
        _append('completed');
      case BoatMediaWarning(:final code, :final message):
        _append('warning $code: $message');
      case BoatMediaError(:final code, :final message):
        lastError.value = '$code: $message';
        _append('error $code: $message');
      case BoatMediaPreempted(:final reason):
        // Preemption is surfaced, never silent.
        preemptionReason.value = reason;
        _append('preempted: $reason');
    }
  }

  void _append(String line) {
    log.value = [...log.value, line];
  }

  Future<void> start() async {
    lastError.value = null;
    preemptionReason.value = null;
    try {
      await player.start();
      _append('started');
    } on BoatMediaBusyException catch (e) {
      lastError.value = 'busy: ${e.message}';
      _append('start refused — voice engine owns the session');
    } on BoatMediaException catch (e) {
      lastError.value = e.message;
      _append('start failed: ${e.message}');
    }
  }

  Future<void> stop() async {
    await player.stop();
    _append('stopped');
  }

  Future<void> playAsset(String assetKey, {bool loop = false}) async {
    isLooping.value = loop;
    try {
      await player.playAsset(assetKey, loop: loop);
      sourceKind.value = BoatMediaSourceKind.asset;
      _append('playing $assetKey');
    } on BoatMediaException catch (e) {
      lastError.value = e.message;
      _append('play failed: ${e.message}');
    }
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> resume() async {
    await player.resume();
  }

  Future<void> seekToFraction(double fraction) async {
    final total = durationMs.value;
    if (total <= 0) return;
    await player.seek(Duration(milliseconds: (total * fraction).round()));
  }

  Future<void> setVolume(double value) async {
    volume.value = value;
    await player.setVolume(value);
  }

  Future<void> flush() async {
    await player.flush();
    _append('flushed');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
