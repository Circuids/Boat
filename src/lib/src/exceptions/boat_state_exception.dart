import 'boat_exception.dart';

/// Invalid state transition attempted.
class BoatStateException extends BoatException {
  const BoatStateException(super.message, {super.code});
}
