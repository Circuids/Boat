import 'boat_media_event.dart';

/// Fatal condition on the media bus. The bus transitions to `error`.
class BoatMediaError extends BoatMediaEvent {
  final String code;
  final String message;

  const BoatMediaError({
    required super.timestamp,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'BoatMediaError($code: $message)';
}
