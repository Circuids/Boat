/// Lifecycle states of [BoatEngine].
enum BoatState {
  /// Created, not started.
  idle,

  /// Initializing native audio resources.
  starting,

  /// Capture and playback active.
  running,

  /// Suspended — native resources held but not processing.
  paused,

  /// Releasing native audio resources.
  stopping,

  /// Terminal — engine cannot be restarted.
  disposed,

  /// Unrecoverable error. See last event for details.
  error,
}
