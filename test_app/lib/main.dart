import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/boat_engine_service.dart';
import 'services/metrics_collector.dart';
import 'services/mock_audio_server.dart';
import 'viewmodels/app_viewmodel.dart';

void main() {
  FairyLocator.registerSingleton<BoatEngineService>(BoatEngineService());
  FairyLocator.registerSingleton<MockAudioServer>(
    MockAudioServer(FairyLocator.get<BoatEngineService>()),
  );
  FairyLocator.registerSingleton<MetricsCollector>(MetricsCollector());
  FairyLocator.registerSingleton<AppViewModel>(
    AppViewModel(FairyLocator.get<BoatEngineService>()),
  );

  runApp(const BoatTestApp());
}

class BoatTestApp extends StatelessWidget {
  const BoatTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boat Real-World Test',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}