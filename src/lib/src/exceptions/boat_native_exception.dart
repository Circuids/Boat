import 'boat_exception.dart';

/// Native audio subsystem failure.
class BoatNativeException extends BoatException {
  const BoatNativeException(super.message, {super.code});
}
