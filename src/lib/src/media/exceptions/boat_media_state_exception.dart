import 'boat_media_exception.dart';

/// A media operation was attempted in a state that does not permit it.
class BoatMediaStateException extends BoatMediaException {
  const BoatMediaStateException(super.message, {super.code});
}
