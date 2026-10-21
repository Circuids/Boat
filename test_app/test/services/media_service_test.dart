import 'package:boat/boat_media.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_media_platform.dart';

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

  test('plays a WAV asset after start', () async {
    await player.start();
    await player.playAsset('assets/wav/click.wav');
    expect(platform.calls, contains('playAsset:assets/wav/click.wav'));
    expect(player.state, BoatMediaState.playing);
  });

  test('surfaces BoatMediaBusyException when voice owns the session', () async {
    platform.startError = const BoatMediaBusyException(
      'voice owns the session',
      code: 'MEDIA_BUSY',
    );
    await expectLater(player.start(), throwsA(isA<BoatMediaBusyException>()));
  });

  test('preemption event reaches the player and returns it to idle', () async {
    await player.start();
    await player.playAsset('assets/wav/click.wav');

    platform.emit(
      BoatMediaPreempted(
        timestamp: DateTime.now(),
        reason: 'voiceEngineStarted',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(player.state, BoatMediaState.idle);
  });

  test('preemption event is observable on the events stream', () async {
    await player.start();
    final seen = <String>[];
    final sub = player.events
        .where((e) => e is BoatMediaPreempted)
        .cast<BoatMediaPreempted>()
        .listen((e) => seen.add(e.reason));

    platform.emit(
      BoatMediaPreempted(
        timestamp: DateTime.now(),
        reason: 'voiceEngineStarted',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['voiceEngineStarted']);
    await sub.cancel();
  });

  test('volume is clamped before reaching the platform', () async {
    await player.start();
    await player.playAsset('assets/wav/click.wav');
    await player.setVolume(5.0);
    expect(platform.calls, contains('setVolume:1.0'));
  });
}
