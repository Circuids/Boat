import 'dart:typed_data';

import 'package:boat/boat.dart';
import 'package:boat_diagnostics/services/metrics_collector.dart';
import 'package:flutter_test/flutter_test.dart';

AudioFrame _frame(int seq, {int? tsMs}) => AudioFrame(
      pcm: Uint8List(640),
      sequenceNumber: seq,
      timestamp: Duration(milliseconds: tsMs ?? seq * 20),
      sampleRate: 16000,
      channelCount: 1,
    );

void main() {
  late MetricsCollector metrics;

  setUp(() {
    metrics = MetricsCollector();
  });

  test('counts capture frames', () {
    metrics.onCaptureFrame(_frame(0));
    metrics.onCaptureFrame(_frame(1));
    metrics.onCaptureFrame(_frame(2));
    expect(metrics.captureFrameCount.value, 3);
  });

  test('detects no drops for contiguous sequence', () {
    for (var i = 0; i < 10; i++) {
      metrics.onCaptureFrame(_frame(i));
    }
    expect(metrics.droppedFrames.value, 0);
  });

  test('detects sequence gaps as dropped frames', () {
    metrics.onCaptureFrame(_frame(0));
    metrics.onCaptureFrame(_frame(1));
    metrics.onCaptureFrame(_frame(5)); // gap of 3 (2,3,4)
    expect(metrics.droppedFrames.value, 3);
  });

  test('accumulates drops across multiple gaps', () {
    metrics.onCaptureFrame(_frame(0));
    metrics.onCaptureFrame(_frame(3)); // drop 2
    metrics.onCaptureFrame(_frame(7)); // drop 3
    expect(metrics.droppedFrames.value, 5);
  });

  test('counts playback frames', () {
    metrics.onPlayback();
    metrics.onPlayback();
    expect(metrics.playbackFrameCount.value, 2);
  });

  test('reset zeroes all counters', () {
    metrics.onCaptureFrame(_frame(0));
    metrics.onCaptureFrame(_frame(5));
    metrics.onPlayback();
    metrics.reset();
    expect(metrics.captureFrameCount.value, 0);
    expect(metrics.droppedFrames.value, 0);
    expect(metrics.playbackFrameCount.value, 0);
    expect(metrics.estimatedLatencyMs.value, 0.0);
  });

  test('reset clears sequence baseline so next frame is not a drop', () {
    metrics.onCaptureFrame(_frame(10));
    metrics.reset();
    metrics.onCaptureFrame(_frame(11));
    expect(metrics.droppedFrames.value, 0);
  });

  test('latency is reasonable (not epoch-scale)', () {
    metrics.onCaptureFrame(_frame(0, tsMs: 0));
    // Latency should be near-zero, not trillions of ms.
    expect(metrics.estimatedLatencyMs.value, lessThan(1000));
    expect(metrics.estimatedLatencyMs.value, greaterThanOrEqualTo(0));
  });

  test('latency reflects delivery delay relative to capture start', () async {
    metrics.onCaptureFrame(_frame(0, tsMs: 0));
    // Wait 50ms, then deliver a frame that claims it was captured at 20ms.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    metrics.onCaptureFrame(_frame(1, tsMs: 20));
    // Elapsed ~50ms, frame timestamp 20ms → latency ~30ms.
    expect(metrics.estimatedLatencyMs.value, greaterThan(10));
    expect(metrics.estimatedLatencyMs.value, lessThan(100));
  });

  test('latency stays non-negative when frames predate collector start', () {
    // Engine started ~3.7s before the conversation: first frame already carries
    // a large engine-relative timestamp. Must not produce negative latency.
    metrics.onCaptureFrame(_frame(0, tsMs: 3717));
    expect(metrics.estimatedLatencyMs.value, greaterThanOrEqualTo(0));
    expect(metrics.estimatedLatencyMs.value, lessThan(1000));
  });

  test('latency measures delivery offset independent of engine start', () async {
    metrics.onCaptureFrame(_frame(0, tsMs: 3717));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    metrics.onCaptureFrame(_frame(1, tsMs: 3737)); // +20ms frame offset
    // ~50ms wall elapsed, 20ms frame offset → ~30ms, regardless of the 3717 base.
    expect(metrics.estimatedLatencyMs.value, greaterThan(10));
    expect(metrics.estimatedLatencyMs.value, lessThan(100));
  });
}