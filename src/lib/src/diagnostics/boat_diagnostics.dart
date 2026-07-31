import '../common/audio_effect_type.dart';
import '../common/audio_route.dart';
import 'effect_status.dart';

/// Snapshot of engine diagnostics and audio effect status.
class BoatDiagnostics {
  final String deviceModel;
  final String osVersion;
  final int audioSessionId;
  final Map<AudioEffectType, EffectStatus> effectStatus;
  final AudioRoute currentRoute;
  final List<AudioRoute> availableRoutes;
  final int captureFrameCount;
  final int playbackFrameCount;
  final Duration uptime;

  /// True if a Bluetooth HFP/SCO device is connected (e.g. Phone Link, car kit).
  /// An active SCO link couples capture to 8 kHz narrowband — expect degraded quality.
  final bool scoDeviceConnected;

  const BoatDiagnostics({
    required this.deviceModel,
    required this.osVersion,
    required this.audioSessionId,
    required this.effectStatus,
    required this.currentRoute,
    required this.availableRoutes,
    required this.captureFrameCount,
    required this.playbackFrameCount,
    required this.uptime,
    this.scoDeviceConnected = false,
  });

  /// Deserializes from a platform channel map.
  ///
  /// Unknown effect keys and route strings are skipped (not mapped to a
  /// default) so stale or unsupported values don't silently masquerade as
  /// a real effect/route.
  factory BoatDiagnostics.fromMap(Map<String, dynamic> map) {
    final effectsRaw = map['effectStatus'];
    final effects = <AudioEffectType, EffectStatus>{};
    if (effectsRaw is Map) {
      for (final entry in effectsRaw.entries) {
        final key = entry.key;
        if (key is! String) continue;
        AudioEffectType? type;
        for (final e in AudioEffectType.values) {
          if (e.name == key) {
            type = e;
            break;
          }
        }
        if (type == null) continue;
        final value = entry.value;
        if (value is! Map) continue;
        final v = Map<String, dynamic>.from(value);
        effects[type] = EffectStatus(
          supported: v['supported'] as bool? ?? false,
          available: v['available'] as bool? ?? false,
          active: v['active'] as bool? ?? false,
        );
      }
    }

    final routes = <AudioRoute>[];
    for (final e in (map['availableRoutes'] as List<dynamic>? ?? [])) {
      if (e is! String) continue;
      try {
        routes.add(AudioRoute.fromString(e));
      } catch (_) {
        // Skip unknown route strings — don't crash the whole parse.
      }
    }

    return BoatDiagnostics(
      deviceModel: map['deviceModel'] as String? ?? '',
      osVersion: map['osVersion'] as String? ?? '',
      audioSessionId: map['audioSessionId'] as int? ?? -1,
      effectStatus: effects,
      currentRoute: AudioRoute.fromString(
        map['currentRoute'] as String? ?? 'speaker',
      ),
      availableRoutes: routes,
      captureFrameCount: map['captureFrameCount'] as int? ?? 0,
      playbackFrameCount: map['playbackFrameCount'] as int? ?? 0,
      uptime: Duration(milliseconds: map['uptimeMs'] as int? ?? 0),
      scoDeviceConnected: map['scoDeviceConnected'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'BoatDiagnostics(device: $deviceModel, os: $osVersion, '
      'session: $audioSessionId, route: $currentRoute, '
      'captureFrames: $captureFrameCount, playbackFrames: $playbackFrameCount, '
      'sco: $scoDeviceConnected)';
}
