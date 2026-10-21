/// Independent media playback bus for Boat.
///
/// Import this barrel to play application media (UI sounds, notification cues,
/// bundled WAV clips) without pulling in the voice engine's surface.
///
/// Media and voice are mutually exclusive owners of the OS audio session — see
/// [BoatMediaPlayer].
library;

export 'src/media/media.dart';
