import 'dart:async';

import 'package:boat/boat.dart';
import 'package:fairy/fairy.dart';

/// Holds the single [BoatEngine] instance for the app lifetime.
///
/// Does not wrap the engine API — ViewModels call [BoatEngine] directly to
/// preserve the plugin's public contract. Registered as a [FairyLocator]
/// singleton to enforce the single-engine constraint.
class BoatEngineService with Disposable {
  final engine = BoatEngine();

  @override
  void dispose() {
    // engine.dispose() is async and terminal; swallow transition errors on
    // teardown (engine may be in a non-disposable state if interrupted).
    unawaited(engine.dispose().catchError((_) {}));
    super.dispose();
  }
}