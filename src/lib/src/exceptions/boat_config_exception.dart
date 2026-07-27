import 'boat_exception.dart';

/// Invalid configuration provided to [BoatEngine].
class BoatConfigException extends BoatException {
  const BoatConfigException(super.message, {super.code});
}
