import 'dart:async';

import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';

import '../services/boat_engine_service.dart';

/// Global app state: the single [BoatEngine] lifecycle and event stream.
///
/// Registered as a [FairyLocator] singleton because the engine instance must
/// outlive any single screen.
class AppViewModel extends ObservableObject {
  final BoatEngineService _engineService;

  final engineState = ObservableProperty<BoatState>(BoatState.idle);
  final lastEvent = ObservableProperty<String>('');

  StreamSubscription<BoatEvent>? _eventSub;
  void Function()? _stateListener;

  AppViewModel(this._engineService) {
    _eventSub = engine.events.listen(_onEvent);
    _stateListener = engineState.propertyChanged(() {
      // Re-evaluate command availability when engine state changes.
      startEngineCommand.notifyCanExecuteChanged();
      stopEngineCommand.notifyCanExecuteChanged();
    });
  }

  BoatEngine get engine => _engineService.engine;

  late final startEngineCommand = AsyncRelayCommand(
    _startEngine,
    canExecute: () => engineState.value == BoatState.idle,
  );

  late final stopEngineCommand = AsyncRelayCommand(
    _stopEngine,
    canExecute: () =>
        engineState.value == BoatState.running ||
        engineState.value == BoatState.paused,
  );

  Future<void> _startEngine() async {
    final status = await BoatPermission.request(PermissionType.microphone);
    if (status != PermissionStatus.granted) {
      lastEvent.value = 'Permission denied: $status';
      return;
    }
    // Optimistically update state so canExecute re-evaluates immediately,
    // preventing a double-tap before the BoatStateChanged event arrives.
    engineState.value = BoatState.starting;
    try {
      await engine.start();
    } catch (e) {
      lastEvent.value = 'Start failed: $e';
      engineState.value = BoatState.idle;
    }
  }

  Future<void> _stopEngine() async {
    try {
      await engine.stop();
    } catch (e) {
      lastEvent.value = 'Stop failed: $e';
    }
  }

  Future<BoatDiagnostics> get diagnostics => engine.diagnostics;

  Future<void> reconfigure(BoatConfig config) => engine.reconfigure(config);

  Future<void> setRoute(AudioRoute route) => engine.setRoute(route);

  void _onEvent(BoatEvent event) {
    lastEvent.value = event.toString();
    if (event is BoatStateChanged) {
      engineState.value = event.current;
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _stateListener?.call();
    super.dispose();
  }
}