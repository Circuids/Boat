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
  });

  /// Deserializes from a platform channel map.
  factory BoatDiagnostics.fromMap(Map<String, dynamic> map) {
    final effectsRaw = map['effectStatus'];
    final effects = <AudioEffectType, EffectStatus>{};
    if (effectsRaw is Map) {
      for (final entry in effectsRaw.entries) {
        final type = AudioEffectType.values.firstWhere(
          (e) => e.name == entry.key,
          orElse: () => AudioEffectType.aec,
        );
        final v = Map<String, dynamic>.from(entry.value as Map);
        effects[type] = EffectStatus(
          supported: v['supported'] as bool? ?? false,
          available: v['available'] as bool? ?? false,
          active: v['active'] as bool? ?? false,
        );
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
      availableRoutes: (map['availableRoutes'] as List<dynamic>? ?? [])
          .map((e) => AudioRoute.fromString(e as String))
          .toList(),
      captureFrameCount: map['captureFrameCount'] as int? ?? 0,
      playbackFrameCount: map['playbackFrameCount'] as int? ?? 0,
      uptime: Duration(
        milliseconds: map['uptimeMs'] as int? ?? 0,
      ),
    );
  }

  @override
  String toString() =>
      'BoatDiagnostics(device: $deviceModel, os: $osVersion, '
      'session: $audioSessionId, route: $currentRoute, '
      'captureFrames: $captureFrameCount, playbackFrames: $playbackFrameCount)';
}
