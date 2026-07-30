import 'dart:typed_data';

import 'package:boat_diagnostics/services/mock_audio_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chunkStream', () {
    test('splits bytes into frame-sized chunks', () async {
      final bytes = Uint8List.fromList(List.generate(1600, (i) => i & 0xFF));
      final chunks = await chunkStream(
        Future.value(bytes),
        640,
      ).toList();

      expect(chunks.length, 3); // 640 + 640 + 320
      expect(chunks[0].bytes.length, 640);
      expect(chunks[1].bytes.length, 640);
      expect(chunks[2].bytes.length, 320);
    });

    test('progress increases monotonically within [0, 1)', () async {
      final bytes = Uint8List(2000);
      final chunks = await chunkStream(Future.value(bytes), 500).toList();
      final progresses = chunks.map((c) => c.progress).toList();

      for (var i = 1; i < progresses.length; i++) {
        expect(progresses[i], greaterThan(progresses[i - 1]));
      }
      expect(progresses.first, 0.0);
      expect(progresses.last, lessThan(1.0));
    });

    test('empty input yields no chunks', () async {
      final chunks = await chunkStream(
        Future.value(Uint8List(0)),
        640,
      ).toList();
      expect(chunks, isEmpty);
    });

    test('chunk smaller than frame size produces one partial chunk', () async {
      final bytes = Uint8List(100);
      final chunks = await chunkStream(Future.value(bytes), 640).toList();
      expect(chunks.length, 1);
      expect(chunks[0].bytes.length, 100);
      expect(chunks[0].progress, 0.0);
    });
  });
}