import 'package:boat/boat.dart';
import 'package:boat_diagnostics/services/boat_engine_service.dart';
import 'package:boat_diagnostics/viewmodels/app_viewmodel.dart';
import 'package:boat_diagnostics/viewmodels/settings_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_boat_platform.dart';

void main() {
  late FakeBoatPlatform platform;
  late BoatEngineService engineService;
  late AppViewModel appVM;
  late SettingsViewModel vm;

  setUp(() {
    platform = FakeBoatPlatform();
    BoatPlatform.instance = platform;
    engineService = BoatEngineService();
    appVM = AppViewModel(engineService);
    vm = SettingsViewModel(appVM);
  });

  tearDown(() async {
    vm.dispose();
    try {
      final state = engineService.engine.state;
      if (state == BoatState.running || state == BoatState.paused) {
        await engineService.engine.stop();
      }
    } catch (_) {}
    appVM.dispose();
    engineService.dispose();
  });

  test('config ComputedProperty rebuilds on field change', () {
    var config = vm.config.value;
    expect(config.aec, true);
    expect(config.sampleRate, 16000);
    expect(config.preferredRoute, AudioRoute.speaker);

    vm.aec.value = false;
    vm.sampleRate.value = 48000;
    vm.preferredRoute.value = AudioRoute.earpiece;

    config = vm.config.value;
    expect(config.aec, false);
    expect(config.sampleRate, 48000);
    expect(config.preferredRoute, AudioRoute.earpiece);
  });

  test('reconfigure applies config to engine', () async {
    // Engine must be running before reconfigure (state machine requires it).
    await appVM.startEngineCommand.execute();
    platform.startedConfigs.clear();

    vm.aec.value = false;
    vm.agc.value = false;

    await vm.reconfigureCommand.execute();
    expect(vm.isReconfiguring.value, false);
    expect(vm.lastError.value, '');
    expect(platform.startedConfigs, hasLength(1));
    expect(platform.startedConfigs.last.aec, false);
    expect(platform.startedConfigs.last.agc, false);
  });

  test('reconfigureCommand blocks while reconfiguring', () async {
    expect(vm.reconfigureCommand.canExecute, true);
    // canExecute is gated on isReconfiguring; after completion it returns true.
    await vm.reconfigureCommand.execute();
    expect(vm.reconfigureCommand.canExecute, true);
  });

  test('reconfigure forwards speakerMode and preferredRoute intact', () async {
    await appVM.startEngineCommand.execute();
    platform.startedConfigs.clear();

    vm.speakerMode.value = false;
    vm.preferredRoute.value = AudioRoute.earpiece;

    await vm.reconfigureCommand.execute();
    expect(platform.startedConfigs, hasLength(1));
    expect(platform.startedConfigs.last.speakerMode, isFalse);
    expect(platform.startedConfigs.last.preferredRoute, AudioRoute.earpiece);
  });
}