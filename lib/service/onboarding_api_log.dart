import 'package:flutter/foundation.dart';

/// Console lines for every onboarding API call. All of them start with
/// `ONB_API`, so the console can be filtered by that word.
///
///   `ONB_API | <STEP> | BEFORE | <METHOD> <url> | request body=...`
///   `ONB_API | <STEP> | AFTER  | status=<code> | response body=...`
///
/// Call [onbBefore] right before the request and [onbAfter] right after the
/// response. Use [onbFailed] when the call throws (no internet, timeout).
void onbBefore(String step, String method, String url, [Object? requestBody]) {
  debugPrint(
    'ONB_API | $step | BEFORE | $method $url | request body=${_show(requestBody)}',
  );
}

void onbAfter(String step, int statusCode, String responseBody) {
  debugPrint(
    'ONB_API | $step | AFTER  | status=$statusCode | response body=${_show(responseBody)}',
  );
}

void onbFailed(String step, Object error) {
  debugPrint('ONB_API | $step | AFTER  | FAILED (no response) | error=$error');
}

String _show(Object? value) {
  var text = value == null ? '-' : value.toString();
  if (text.isEmpty) text = '-';
  // The face selfie (base64) is huge; keep only its size.
  text = text.replaceAllMapped(
    RegExp(r'"([a-z_]*base64[a-z_]*)"\s*:\s*"[^"]{200,}"'),
    (m) => '"${m[1]}":"<base64 hidden>"',
  );
  return text.length <= 3000 ? text : '${text.substring(0, 3000)}... [clipped]';
}
