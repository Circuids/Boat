import 'dart:async';

import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter/services.dart';

import 'boat_engine_service.dart';

/// Simulates the server side of a voice conversation by streaming a bundled
/// PCM asset to [BoatEngine.playRaw] in frame-sized chunks, mimicking realtime
/// AI response delivery over a network.
///
/// Boat has no networking by design; this mock reproduces the acoustic loop
/// (playback overlapping capture) without coupling to transport behavior.
class MockAudioServer with Disposable {
  final BoatEngineService _engineService;

  MockAudioServer(this._engineService);

  /// Streams [assetPath] to `engine.playRaw()` in 20ms chunks.
  ///
  /// Yields playback progress 0.0–1.0. The 20ms pacing matches
  /// `BoatConfig.bufferDurationMs` default, simulating realtime delivery.
  /// Cancelling the subscription stops playback mid-stream.
  Stream<double> playResponse(String assetPath, {int frameBytes = 640}) {
    final chunks = chunkStream(_loadAsset(assetPath), frameBytes);
    return chunks.asyncMap((chunk) async {
      throwIfDisposed();
      _engineService.engine.playRaw(chunk.bytes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return chunk.progress;
    });
  }

  /// Stops any in-flight playback immediately (barge-in).
  Future<void> flush() => _engineService.engine.flushPlayback();

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// A single chunk of PCM data with its playback progress (0.0–1.0).
class PcmChunk {
  final Uint8List bytes;
  final double progress;
  const PcmChunk(this.bytes, this.progress);
}

/// Splits [bytes] into [frameBytes]-sized chunks, yielding each with its
/// progress fraction. Pure function — no I/O, no platform calls — so it can
/// be unit tested without Flutter or a running engine.
Stream<PcmChunk> chunkStream(Future<Uint8List> bytes, int frameBytes) async* {
  final data = await bytes;
  for (var offset = 0; offset < data.length; offset += frameBytes) {
    final end = offset + frameBytes > data.length
        ? data.length
        : offset + frameBytes;
    yield PcmChunk(
      Uint8List.sublistView(data, offset, end),
      offset / data.length,
    );
  }
}