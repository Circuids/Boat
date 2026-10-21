import 'dart:async';
import 'dart:typed_data';

import 'package:boat/boat_media.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake so the player's state machine and error mapping can be
/// exercised without a platform channel.
class FakeMediaPlatform implements BoatMediaPlatform {
  final StreamController<BoatMediaEvent> _events =
      StreamController<BoatMediaEvent>.broadcast();

  final List<String> calls = [];

  /// When set, the next matching call throws this.
  Object? startError;
  Object? playError;

  BoatMediaState _state = BoatMediaState.idle;
  final BoatMediaStatus _status = const BoatMediaStatus(
    state: BoatMediaState.idle,
    position: Duration.zero,
    duration: null,
    volume: 1.0,
    sourceKind: BoatMediaSourceKind.none,
    loop: false,
  );

  @override
  BoatMediaState get state => _state;

  @override
  Stream<BoatMediaEvent> get events => _events.stream;

  @override
  Future<BoatMediaStatus> get status async => _status;

  void emit(BoatMediaEvent event) => _events.add(event);

  @override
  Future<void> start(BoatMediaConfig config) async {
    calls.add('start');
    if (startError != null) throw startError!;
    _state = BoatMediaState.loading;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _state = BoatMediaState.idle;
  }

  @override
  Future<void> playPcm(Uint8List pcm) async {
    calls.add('playPcm');
    if (playError != null) throw playError!;
  }

  @override
  Future<void> playFile(String path, {bool loop = false}) async {
    calls.add('playFile:$path');
    if (playError != null) throw playError!;
  }

  @override
  Future<void> playAsset(String assetKey, {bool loop = false}) async {
    calls.add('playAsset:$assetKey');
    if (playError != null) throw playError!;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> setVolume(double volume) async => calls.add('setVolume:$volume');

  @override
  Future<void> flush() async => calls.add('flush');
}

void main() {
  late FakeMediaPlatform platform;
  late BoatMediaPlayer player;

  setUp(() {
    platform = FakeMediaPlatform();
    player = BoatMediaPlayer(platform: platform);
  });

  tearDown(() async {
    await player.dispose();
  });

  group('lifecycle', () {
    test('starts idle', () {
      expect(player.state, BoatMediaState.idle);
    });

    test('start acquires the session and moves to loading', () async {
      await player.start();
      expect(player.state, BoatMediaState.loading);
      expect(platform.calls, contains('start'));
    });

    test('start is idempotent while already started', () async {
      await player.start();
      await player.start();
      expect(platform.calls.where((c) => c == 'start').length, 1);
    });

    test('stop returns to idle', () async {
      await player.start();
      await player.stop();
      expect(player.state, BoatMediaState.idle);
    });

    test('start after stop works again', () async {
      await player.start();
      await player.stop();
      await player.start();
      expect(player.state, BoatMediaState.loading);
    });
  });

  group('mutual exclusion', () {
    test('start surfaces BoatMediaBusyException from native', () async {
      platform.startError = const BoatMediaBusyException(
        'voice owns the session',
        code: 'MEDIA_BUSY',
      );
      await expectLater(player.start(), throwsA(isA<BoatMediaBusyException>()));
      expect(player.state, BoatMediaState.error);
    });

    test('preemption event returns the player to idle', () async {
      await player.start();
      await player.playFile('/a.wav');
      expect(player.state, BoatMediaState.playing);

      platform.emit(
        BoatMediaPreempted(
          timestamp: DateTime.now(),
          reason: 'voiceEngineStarted',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(player.state, BoatMediaState.idle);
    });
  });

  group('playback guards', () {
    test('playFile before start throws BoatMediaStateException', () async {
      await expectLater(
        player.playFile('/a.wav'),
        throwsA(isA<BoatMediaStateException>()),
      );
      expect(platform.calls, isEmpty);
    });

    test('playPcm before start throws before any channel call', () async {
      await expectLater(
        player.playPcm(Uint8List(4)),
        throwsA(isA<BoatMediaStateException>()),
      );
      expect(platform.calls, isEmpty);
    });

    test('playFile after start plays', () async {
      await player.start();
      await player.playFile('/a.wav');
      expect(player.state, BoatMediaState.playing);
      expect(platform.calls, contains('playFile:/a.wav'));
    });

    test('play* while playing replaces the source without stop()', () async {
      await player.start();
      await player.playFile('/a.wav');
      await player.playFile('/b.wav');
      expect(platform.calls, contains('playFile:/a.wav'));
      expect(platform.calls, contains('playFile:/b.wav'));
      expect(platform.calls, isNot(contains('stop')));
      expect(player.state, BoatMediaState.playing);
    });

    test('pause then resume', () async {
      await player.start();
      await player.playFile('/a.wav');
      await player.pause();
      expect(player.state, BoatMediaState.paused);
      await player.resume();
      expect(player.state, BoatMediaState.playing);
    });
  });

  group('seek', () {
    test('throws for streaming PCM', () async {
      await player.start();
      await player.playPcm(Uint8List(4));
      await expectLater(
        player.seek(const Duration(seconds: 1)),
        throwsA(isA<BoatMediaStateException>()),
      );
      expect(platform.calls.where((c) => c.startsWith('seek')), isEmpty);
    });

    test('works for a file source', () async {
      await player.start();
      await player.playFile('/a.wav');
      await player.seek(const Duration(milliseconds: 500));
      expect(platform.calls, contains('seek:500'));
    });
  });

  group('volume', () {
    test('clamps out-of-range values', () async {
      await player.start();
      await player.playFile('/a.wav');
      await player.setVolume(2.0);
      await player.setVolume(-1.0);
      expect(platform.calls, contains('setVolume:1.0'));
      expect(platform.calls, contains('setVolume:0.0'));
    });
  });

  group('dispose', () {
    test('is terminal — every method throws afterwards', () async {
      await player.start();
      await player.dispose();

      await expectLater(
        player.playFile('/a.wav'),
        throwsA(isA<BoatMediaStateException>()),
      );
      await expectLater(
        player.start(),
        throwsA(isA<BoatMediaStateException>()),
      );
      await expectLater(player.stop(), throwsA(isA<BoatMediaStateException>()));
    });

    test('is idempotent', () async {
      await player.dispose();
      await expectLater(player.dispose(), completes);
    });

    test('while playing stops playback first', () async {
      await player.start();
      await player.playFile('/a.wav');
      await player.dispose();
      expect(platform.calls, contains('stop'));
    });
  });

  group('event stream', () {
    test('emits state changes', () async {
      final seen = <BoatMediaState>[];
      final sub = player.events
          .where((e) => e is BoatMediaStateChanged)
          .cast<BoatMediaStateChanged>()
          .listen((e) => seen.add(e.current));

      await player.start();
      await player.playFile('/a.wav');
      await Future<void>.delayed(Duration.zero);

      expect(seen, [BoatMediaState.loading, BoatMediaState.playing]);
      await sub.cancel();
    });

    test('completion event moves state to completed', () async {
      await player.start();
      await player.playFile('/a.wav');
      platform.emit(BoatMediaCompleted(timestamp: DateTime.now()));
      await Future<void>.delayed(Duration.zero);
      expect(player.state, BoatMediaState.completed);
    });

    test('error event moves state to error', () async {
      await player.start();
      platform.emit(
        BoatMediaError(
          timestamp: DateTime.now(),
          code: 'MEDIA_SOURCE_FAILED',
          message: 'bad wav',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(player.state, BoatMediaState.error);
    });
  });

  group('error mapping', () {
    test('play failure surfaces the typed exception', () async {
      await player.start();
      platform.playError = const BoatMediaFormatException(
        'mismatch',
        code: 'MEDIA_FORMAT_MISMATCH',
      );
      await expectLater(
        player.playPcm(Uint8List(4)),
        throwsA(isA<BoatMediaFormatException>()),
      );
    });
  });
}
