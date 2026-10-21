import 'dart:typed_data';

import 'events/boat_media_events.dart';
import 'models/boat_media_config.dart';
import 'models/boat_media_state.dart';
import 'models/boat_media_status.dart';

/// Platform interface for the media bus.
///
/// Deliberately separate from `BoatPlatform`: adding media members there would
/// force every platform implementer to implement media.
abstract class BoatMediaPlatform {
  /// Acquires the audio session and creates the media output.
  ///
  /// Throws [BoatMediaBusyException] when the voice engine owns the session.
  Future<void> start(BoatMediaConfig config);

  /// Releases the media session, output, and the arbiter.
  Future<void> stop();

  Future<void> playPcm(Uint8List pcm);
  Future<void> playFile(String path, {bool loop = false});
  Future<void> playAsset(String assetKey, {bool loop = false});
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> flush();

  BoatMediaState get state;
  Stream<BoatMediaEvent> get events;
  Future<BoatMediaStatus> get status;
}
