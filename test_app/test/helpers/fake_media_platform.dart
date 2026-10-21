import 'dart:async';
import 'dart:typed_data';

import 'package:boat/boat_media.dart';

/// In-memory [BoatMediaPlatform] for service/view-model tests.
class FakeMediaPlatform implements BoatMediaPlatform {
  final StreamController<BoatMediaEvent> _events =
      StreamController<BoatMediaEvent>.broadcast();

  final List<String> calls = [];
  Object? startError;

  BoatMediaState _state = BoatMediaState.idle;

  @override
  BoatMediaState get state => _state;

  @override
  Stream<BoatMediaEvent> get events => _events.stream;

  @override
  Future<BoatMediaStatus> get status async => BoatMediaStatus(
    state: _state,
    position: Duration.zero,
    duration: null,
    volume: 1.0,
    sourceKind: BoatMediaSourceKind.none,
    loop: false,
  );

  void emit(BoatMediaEvent event) => _events.add(event);

  @override
  Future<void> start(BoatMediaConfig config) async {
    calls.add('start');
    if (startError != null) throw startError!;
    _state = BoatMediaState.loading;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _state = BoatMediaState.idle;
  }

  @override
  Future<void> playPcm(Uint8List pcm) async => calls.add('playPcm');

  @override
  Future<void> playFile(String path, {bool loop = false}) async =>
      calls.add('playFile:$path');

  @override
  Future<void> playAsset(String assetKey, {bool loop = false}) async =>
      calls.add('playAsset:$assetKey');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> setVolume(double volume) async => calls.add('setVolume:$volume');

  @override
  Future<void> flush() async => calls.add('flush');
}
