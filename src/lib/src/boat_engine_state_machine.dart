import 'common/boat_state.dart';
import 'exceptions/boat_state_exception.dart';

/// Enforces valid state transitions per the lifecycle state machine.
class BoatEngineStateMachine {
  BoatState _current = BoatState.idle;

  BoatState get current => _current;

  static const _validTransitions = <BoatState, Set<BoatState>>{
    BoatState.idle: {BoatState.starting, BoatState.disposed},
    BoatState.starting: {
      BoatState.running,
      BoatState.error,
      BoatState.stopping,
    },
    BoatState.running: {BoatState.paused, BoatState.stopping, BoatState.error},
    BoatState.paused: {BoatState.running, BoatState.stopping, BoatState.error},
    BoatState.stopping: {BoatState.idle, BoatState.error},
    BoatState.error: {BoatState.stopping, BoatState.disposed},
    BoatState.disposed: {},
  };

  void transition(BoatState next) {
    final allowed = _validTransitions[_current] ?? {};
    if (!allowed.contains(next)) {
      throw BoatStateException(
        'Invalid transition: $_current → $next',
        code: 'INVALID_TRANSITION',
      );
    }
    _current = next;
  }
}
