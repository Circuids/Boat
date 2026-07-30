import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';

import 'app_viewmodel.dart';

/// Exposes every [BoatConfig] field as an [ObservableProperty], with a
/// [ComputedProperty] that rebuilds the config. A reconfigure command applies
/// the config to the running engine via [BoatEngine.reconfigure].
class SettingsViewModel extends ObservableObject {
  final AppViewModel _appVM;

  final sampleRate = ObservableProperty<int>(16000);
  final aec = ObservableProperty<bool>(true);
  final agc = ObservableProperty<bool>(true);
  final noiseSuppression = ObservableProperty<bool>(true);
  final speakerMode = ObservableProperty<bool>(true);
  final preferredRoute = ObservableProperty<AudioRoute>(AudioRoute.speaker);

  late final config = ComputedProperty<BoatConfig>(
    () => BoatConfig(
      sampleRate: sampleRate.value,
      aec: aec.value,
      agc: agc.value,
      noiseSuppression: noiseSuppression.value,
      speakerMode: speakerMode.value,
      preferredRoute: preferredRoute.value,
    ),
    [sampleRate, aec, agc, noiseSuppression, speakerMode, preferredRoute],
    this,
  );

  final isReconfiguring = ObservableProperty<bool>(false);
  final lastError = ObservableProperty<String>('');

  SettingsViewModel(this._appVM);

  late final reconfigureCommand = AsyncRelayCommand(
    _reconfigure,
    canExecute: () => !isReconfiguring.value,
  );

  Future<void> _reconfigure() async {
    isReconfiguring.value = true;
    try {
      await _appVM.reconfigure(config.value);
    } catch (e) {
      lastError.value = 'Reconfigure failed: $e';
    } finally {
      isReconfiguring.value = false;
    }
  }
}