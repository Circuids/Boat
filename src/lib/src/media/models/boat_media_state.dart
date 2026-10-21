/// Lifecycle state of [BoatMediaPlayer].
///
/// Independent of `BoatState` — the media bus has its own state machine and
/// never participates in the voice engine's lifecycle.
enum BoatMediaState {
  /// Created but not started. No OS audio session is held.
  idle,

  /// Session acquired; no source has been played yet.
  loading,

  /// A source is actively playing.
  playing,

  /// Playback suspended; position retained.
  paused,

  /// A non-looping source reached its end.
  completed,

  /// Unrecoverable failure. See the last [BoatMediaError] event.
  error,
}
