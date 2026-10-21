/// Base exception for all media bus errors.
///
/// Concrete so unmapped native failures (`MEDIA_SOURCE_FAILED`,
/// `MEDIA_START_FAILED`) can be thrown directly rather than inventing a
/// subclass per code.
class BoatMediaException implements Exception {
  final String message;
  final String? code;

  const BoatMediaException(this.message, {this.code});

  @override
  String toString() =>
      'BoatMediaException${code != null ? '($code)' : ''}: $message';
}
