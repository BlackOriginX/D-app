import 'package:flutter/foundation.dart';

/// Console lines for ride API calls. All start with `RIDE_API`, so the console
/// can be filtered by that word:
///
///   RIDE_API | PAYMENT QR | BEFORE | POST <url> | request body=...
///   RIDE_API | PAYMENT QR | AFTER  | status=<code> | response body=...
void rideBefore(String step, String method, String url, [Object? requestBody]) {
  if (!kDebugMode) return; // never log request bodies in a release build
  debugPrint(
    'RIDE_API | $step | BEFORE | $method $url | request body=${_show(requestBody)}',
  );
}

void rideAfter(String step, int statusCode, String responseBody) {
  if (!kDebugMode) return;
  debugPrint(
    'RIDE_API | $step | AFTER  | status=$statusCode | response body=${_show(responseBody)}',
  );
}

void rideFailed(String step, Object error) {
  if (!kDebugMode) return;
  debugPrint('RIDE_API | $step | AFTER  | FAILED (no response) | error=$error');
}

String _show(Object? value) {
  final text = value == null || value.toString().isEmpty
      ? '-'
      : value.toString();
  return text.length <= 3000 ? text : '${text.substring(0, 3000)}... [clipped]';
}
