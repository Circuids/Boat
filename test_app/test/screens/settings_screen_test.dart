import 'package:boat/boat.dart';
import 'package:boat_diagnostics/main.dart';
import 'package:boat_diagnostics/services/boat_engine_service.dart';
import 'package:boat_diagnostics/services/metrics_collector.dart';
import 'package:boat_diagnostics/services/mock_audio_server.dart';
import 'package:boat_diagnostics/viewmodels/app_viewmodel.dart';
import 'package:fairy/fairy.dart';
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

  testWidgets('settings shows Speaker Mode toggle and Preferred route', (tester) async {
    await tester.pumpWidget(const BoatTestApp());
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(find.text('Speaker Mode'), findsOneWidget);
    expect(find.text('Preferred route'), findsOneWidget);
  });

  testWidgets('preferred route dropdown shows default speaker', (tester) async {
    await tester.pumpWidget(const BoatTestApp());
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump();

    // DropdownButton renders the current value as text.
    expect(find.text('speaker'), findsOneWidget);
  });
}
