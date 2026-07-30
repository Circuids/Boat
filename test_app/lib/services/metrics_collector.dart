import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';

/// Collects capture/playback metrics for the diagnostics dashboard and AEC
/// validation flow: frame counters, dropped frames (sequence gaps), and
/// estimated capture-to-delivery latency.
///
/// A pure service — not a ViewModel. It owns [ObservableProperty] fields (which
/// work standalone) and is consumed by [ConversationViewModel], which surfaces
/// them to the view. The view never binds to this service directly.
class MetricsCollector with Disposable {
  final captureFrameCount = ObservableProperty<int>(0);
  final droppedFrames = ObservableProperty<int>(0);
  final estimatedLatencyMs = ObservableProperty<double>(0.0);
  final playbackFrameCount = ObservableProperty<int>(0);

  int _lastSeq = -1;
  DateTime? _captureStart;
  Duration _firstFrameTimestamp = Duration.zero;

  /// Updates counters from a captured frame. Sequence gaps indicate dropped
  /// frames — a signal of pipeline starvation under duplex load.
  void onCaptureFrame(AudioFrame frame) {
    throwIfDisposed();
    // Record wall-clock start on first frame to establish a time base, and
    // anchor the frame's engine-relative timestamp to it. frame.timestamp is
    // relative to ENGINE start, which predates this collector's start, so the
    // offset must be subtracted or latency reads negative.
    if (_captureStart == null) {
      _captureStart = DateTime.now();
      _firstFrameTimestamp = frame.timestamp;
    }
    captureFrameCount.value++;
    if (_lastSeq >= 0 && frame.sequenceNumber > _lastSeq + 1) {
      droppedFrames.value += frame.sequenceNumber - _lastSeq - 1;
    }
    _lastSeq = frame.sequenceNumber;
    // Delivery latency = wall-clock elapsed since first frame minus the
    // frame's own offset from the first frame. Independent of engine start.
    final elapsedMs = DateTime.now().difference(_captureStart!).inMilliseconds;
    final frameOffsetMs = (frame.timestamp - _firstFrameTimestamp).inMilliseconds;
    estimatedLatencyMs.value = (elapsedMs - frameOffsetMs).toDouble();
  }

  void onPlayback() {
    throwIfDisposed();
    playbackFrameCount.value++;
  }

  void reset() {
    throwIfDisposed();
    captureFrameCount.value = 0;
    droppedFrames.value = 0;
    estimatedLatencyMs.value = 0.0;
    playbackFrameCount.value = 0;
    _lastSeq = -1;
    _captureStart = null;
    _firstFrameTimestamp = Duration.zero;
  }
}