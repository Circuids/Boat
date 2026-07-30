// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:boat/boat.dart';
import 'package:boat_diagnostics/main.dart';
import 'package:boat_diagnostics/services/boat_engine_service.dart';
import 'package:boat_diagnostics/services/metrics_collector.dart';
import 'package:boat_diagnostics/services/mock_audio_server.dart';
import 'package:boat_diagnostics/viewmodels/app_viewmodel.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_boat_platform.dart';

void main() {
  setUp(() {
    BoatPlatform.instance = FakeBoatPlatform();
    FairyLocator.reset();
    FairyLocator.registerSingleton<BoatEngineService>(BoatEngineService());
    FairyLocator.registerSingleton<MockAudioServer>(
      MockAudioServer(FairyLocator.get<BoatEngineService>()),
    );
    FairyLocator.registerSingleton<MetricsCollector>(MetricsCollector());
    FairyLocator.registerSingleton<AppViewModel>(
      AppViewModel(FairyLocator.get<BoatEngineService>()),
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

  testWidgets('App launches and shows bottom nav', (tester) async {
    await tester.pumpWidget(const BoatTestApp());
    await tester.pump();

    expect(find.text('Conversation'), findsWidgets);
    expect(find.text('Diagnostics'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
