import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';

import 'app_viewmodel.dart';

/// Backs the diagnostics dashboard: refreshes [BoatDiagnostics] on demand.
class DiagnosticsViewModel extends ObservableObject {
  final AppViewModel _appVM;

  final diagnostics = ObservableProperty<BoatDiagnostics?>(null);
  final isRefreshing = ObservableProperty<bool>(false);
  final lastError = ObservableProperty<String>('');

  DiagnosticsViewModel(this._appVM);

  late final refreshCommand = AsyncRelayCommand(
    _refresh,
    canExecute: () => !isRefreshing.value,
  );

  Future<void> _refresh() async {
    isRefreshing.value = true;
    try {
      diagnostics.value = await _appVM.diagnostics;
    } catch (e) {
      lastError.value = 'Diagnostics failed: $e';
    } finally {
      isRefreshing.value = false;
    }
  }
}