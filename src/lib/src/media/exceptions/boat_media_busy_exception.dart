import 'boat_media_exception.dart';

/// The voice engine owns the audio session, so media playback was refused.
///
/// Media and voice are mutually exclusive owners of the OS audio session.
/// Stop the voice engine before starting media playback.
class BoatMediaBusyException extends BoatMediaException {
  const BoatMediaBusyException(super.message, {super.code});
}
