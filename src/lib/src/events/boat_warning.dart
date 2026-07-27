import 'boat_event.dart';

/// Non-fatal warning from the native audio layer.
class BoatWarning extends BoatEvent {
  final String code;
  final String message;

  const BoatWarning({
    required super.timestamp,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'BoatWarning($code: $message)';
}
