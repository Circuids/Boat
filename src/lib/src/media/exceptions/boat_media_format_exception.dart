import 'boat_media_exception.dart';

/// Supplied PCM does not match the configured stream format.
///
/// Resampling consumer bytes silently would hide a real bug, so a mismatch is
/// rejected instead.
class BoatMediaFormatException extends BoatMediaException {
  const BoatMediaFormatException(super.message, {super.code});
}
