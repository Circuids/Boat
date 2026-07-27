/// Base exception for all Boat errors.
abstract class BoatException implements Exception {
  final String message;
  final String? code;

  const BoatException(this.message, {this.code});

  @override
  String toString() =>
      'BoatException${code != null ? '($code)' : ''}: $message';
}
