import 'package:boat/boat.dart';
import 'package:boat_diagnostics/main.dart';
import 'package:boat_diagnostics/services/boat_engine_service.dart';
import 'package:boat_diagnostics/services/media_service.dart';
import 'package:boat_diagnostics/services/metrics_collector.dart';
import 'package:boat_diagnostics/services/mock_audio_server.dart';
import 'package:boat_diagnostics/viewmodels/app_viewmodel.dart';
import 'package:boat_diagnostics/viewmodels/media_viewmodel.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_boat_platform.dart';

void main() {
  late FakeBoatPlatform platform;

  setUp(() {
    platform = FakeBoatPlatform();
    BoatPlatform.instance = platform;
    FairyLocator.reset();
    FairyLocator.registerSingleton<BoatEngineService>(BoatEngineService());
    FairyLocator.registerSingleton<MockAudioServer>(
      MockAudioServer(FairyLocator.get<BoatEngineService>()),
    );
    FairyLocator.registerSingleton<MetricsCollector>(MetricsCollector());
    FairyLocator.registerSingleton<AppViewModel>(
      AppViewModel(FairyLocator.get<BoatEngineService>()),
    );
    FairyLocator.registerSingleton<MediaService>(MediaService());
    FairyLocator.registerSingleton<MediaViewModel>(
      MediaViewModel(FairyLocator.get<MediaService>()),
    );
  });

  tearDown(() {
    final svc = FairyLocator.get<BoatEngineService>();
    if (svc.engine.state == BoatState.running ||
        svc.engine.state == BoatState.paused) {
      svc.engine.stop();
    }
    svc.dispose();
    FairyLocator.reset();
  });

  testWidgets('conversation screen renders phase and controls', (tester) async {
    await tester.pumpWidget(const BoatTestApp());
    await tester.pump();

    // Conversation is the first tab.
    expect(find.text('Conversation'), findsWidgets);
    expect(find.text('Start Conversation'), findsOneWidget);
    expect(find.text('Start Engine'), findsOneWidget);
    expect(find.text('Capture Recording (AEC Verification)'), findsOneWidget);
  });

  testWidgets('diagnostics tab shows refresh prompt', (tester) async {
    await tester.pumpWidget(const BoatTestApp());
    await tester.pump();

    await tester.tap(find.text('Diagnostics'));
    await tester.pump();

    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('No diagnostics yet. Tap Refresh.'), findsOneWidget);
  });

  testWidgets('settings tab shows toggles and reconfigure', (tester) async {
    await tester.pumpWidget(const BoatTestApp());
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(find.text('AEC'), findsOneWidget);
    expect(find.text('AGC'), findsOneWidget);
    expect(find.text('Noise Suppression'), findsOneWidget);

    // The settings list now includes a playback-rate card, so the reconfigure
    // button sits below the fold in the test viewport.
    await tester.scrollUntilVisible(
      find.text('Reconfigure Engine'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reconfigure Engine'), findsOneWidget);
  });
}