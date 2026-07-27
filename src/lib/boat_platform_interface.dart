import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'boat_method_channel.dart';
import 'src/common/common.dart';
import 'src/diagnostics/diagnostics.dart';
import 'src/events/events.dart';
import 'src/models/models.dart';

/// Platform interface for Boat audio engine.
///
/// Platform-specific implementations extend this class and register
/// themselves via [BoatPlatform.instance].
abstract class BoatPlatform extends PlatformInterface {
  BoatPlatform() : super(token: _token);

  static final Object _token = Object();

  static BoatPlatform _instance = MethodChannelBoat();

  /// The default instance of [BoatPlatform] to use.
  static BoatPlatform get instance => _instance;

  /// Platform-specific implementations set this during registration.
  static set instance(BoatPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ── Lifecycle ──

  Future<void> start(BoatConfig config);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
  Future<void> reconfigure(BoatConfig config);

  // ── State ──

  BoatState get state;
  Stream<BoatEvent> get events;

  // ── Audio ──

  Stream<AudioFrame> get captureFrames;
  void play(Uint8List pcm);
  Future<void> flushPlayback();

  // ── Routing ──

  AudioRoute get currentRoute;
  Future<void> setRoute(AudioRoute route);

  // ── Diagnostics ──

  Future<BoatDiagnostics> getDiagnostics();
}
