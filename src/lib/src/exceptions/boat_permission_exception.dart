import 'boat_exception.dart';

/// Missing required permission (e.g. RECORD_AUDIO).
class BoatPermissionException extends BoatException {
  const BoatPermissionException(super.message, {super.code});
}
