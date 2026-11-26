import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/service/token_store.dart';

/// HTTP client that adds `Authorization: Bearer <token>` to every request
/// for our own backend, except the public endpoints.
///
/// Third-party hosts (Gemini, Google Maps, OSRM) never get the token.
class AuthClient extends http.BaseClient {
  AuthClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Called once when the server answers 401 to a request that carried (or
  /// should have carried) the token. Set by [AppBootstrap] to open login.
  static Future<void> Function()? onUnauthorized;

  /// The review/bypass account has no server token; never force it out.
  static const String _bypassPhone = '9999999999';

  static bool _handlingUnauthorized = false;

  static final String _backendHost = Uri.parse(AppUrls.baseUrl).authority;

  /// Other hosts that belong to our own backend and need the login token.
  static final Set<String> _ownHosts = {
    _backendHost,
    Uri.parse(AppUrls.paymentQr).authority,
  };

  static final Set<String> _publicPaths = {
    Uri.parse(AppUrls.sendOtp).path,
    Uri.parse(AppUrls.verifyOtp).path,
    Uri.parse(AppUrls.locationCheck).path,
    Uri.parse(AppUrls.locationNotifyMe).path,
  };

  static bool isProtected(Uri url) =>
      _ownHosts.contains(url.authority) && !_publicPaths.contains(url.path);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var attachedToken = false;
    var sentToken = '';
    if (isProtected(request.url)) {
      final token = await TokenStore.read();
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
        attachedToken = true;
        sentToken = token;
      }
    }
    final response = await _logged(request, attachedToken);
    if (response.statusCode == 401 && isProtected(request.url)) {
      debugPrint(
        '[API] 401 on ${request.method} ${request.url.path} '
        '(token sent: $attachedToken)',
      );
      // Registering the FCM token must never end the session: if that one
      // endpoint rejects the token, only the push registration fails.
      if (request.url.path == Uri.parse(AppUrls.fcmToken).path) {
        debugPrint(
          '[API] 401 on fcm-token ignored (session kept). Ask the backend why '
          'this endpoint rejects a token the driver APIs accept.',
        );
        return response;
      }
      // A reply to a request that was sent BEFORE the driver logged in (or with
      // an older token) must not log out the fresh session. Only a 401 for the
      // token that is saved right now counts.
      final currentToken = await TokenStore.read();
      if (currentToken.isNotEmpty && currentToken != sentToken) {
        debugPrint(
          '[API] 401 ignored: it answers an older request (token changed '
          'since it was sent)',
        );
        return response;
      }
      unawaited(_handleUnauthorized());
    } else if (response.statusCode == 403 && isProtected(request.url)) {
      debugPrint(
        '[API] 403 on ${request.method} ${request.url.path} '
        '(token sent: $attachedToken)',
      );
    }
    return response;
  }

  /// Prints one line before the call (method, URL, request body) and one after
  /// it (status code, time, response body) so every API can be checked in the
  /// console. Debug builds only. The Authorization header is never printed.
  ///
  /// Onboarding APIs also print their own `ONB_API | ...` lines at the call
  /// site (see onboarding_api_log.dart).
  Future<http.StreamedResponse> _logged(
    http.BaseRequest request,
    bool attachedToken,
  ) async {
    if (!kDebugMode) return _inner.send(request);
    const before = '[API] before ->';
    const after = '[API] after  <-';
    final tag = '${request.method} ${request.url}';
    debugPrint(
      '$before $tag (token: $attachedToken) request body=${_requestBody(request)}',
    );
    final clock = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      // Read the body to print it, then hand back an identical response.
      final bytes = await response.stream.toBytes();
      debugPrint(
        '$after $tag status=${response.statusCode} '
        '(${clock.elapsedMilliseconds}ms) response body=${_clip(utf8.decode(bytes, allowMalformed: true))}',
      );
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      debugPrint(
        '$after $tag FAILED (${clock.elapsedMilliseconds}ms) error=$e',
      );
      rethrow;
    }
  }

  static String _requestBody(http.BaseRequest request) {
    if (request is http.Request) {
      return request.body.isEmpty ? '-' : _clip(_hideBigFields(request.body));
    }
    if (request is http.MultipartRequest) {
      final files = [for (final f in request.files) '${f.field}:${f.filename}'];
      return 'multipart fields=${request.fields} files=$files';
    }
    return '<stream>';
  }

  /// Replaces very long base64 values (the face selfie) with their length.
  static String _hideBigFields(String body) => body.replaceAllMapped(
    RegExp(r'"([a-z_]*base64[a-z_]*)"\s*:\s*"[^"]{200,}"'),
    (m) => '"${m[1]}":"<base64 hidden>"',
  );

  static String _clip(String text) =>
      text.length <= 3000 ? text : '${text.substring(0, 3000)}... [clipped]';

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('user_phone') == _bypassPhone) return;
      // Already logged out by an earlier 401: nothing left to do.
      final loggedIn = prefs.getBool('isLoggedIn') ?? false;
      if (!loggedIn && (await TokenStore.read()).isEmpty) return;
      await TokenStore.clear();
      await onUnauthorized?.call();
    } finally {
      _handlingUnauthorized = false;
    }
  }
}

/// Shared client for all backend calls.
final AuthClient apiClient = AuthClient();
