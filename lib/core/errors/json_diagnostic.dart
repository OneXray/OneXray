import 'package:onexray/core/errors/failure.dart';

/// A location supplied by a JSON parser or an App-owned document boundary.
/// Core error messages are never interpreted as paths or source offsets.
class JsonDiagnostic extends FormatException {
  final int length;
  final List<Object>? path;

  const JsonDiagnostic(
    String message, {
    int? offset,
    this.length = 1,
    this.path,
  }) : super(message, null, offset);

  static JsonDiagnostic? fromError(Object? error) {
    if (error is JsonDiagnostic) return error;
    if (error is FormatException) {
      return JsonDiagnostic(error.message, offset: error.offset);
    }
    if (error is AppFailure) return fromError(error.cause);
    return null;
  }

  @override
  String toString() => message;
}
