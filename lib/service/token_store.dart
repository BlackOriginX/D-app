import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The single place the login token is read, saved and cleared.
///
/// Read from prefs every time (no in-memory copy) so the background
/// isolate always sees the token the UI isolate saved.
class TokenStore {
  const TokenStore._();

  static const String _key = 'auth_token';

  /// Older builds saved the token under these keys.
  static const List<String> _legacyKeys = ['token', 'access_token'];

  static Future<String> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final current = prefs.getString(_key);
    if (current != null && current.isNotEmpty) return current;
    for (final key in _legacyKeys) {
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) return legacy;
    }
    return '';
  }

  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
    // Debug only: prove the token really is stored and can be read back.
    await prefs.reload();
    debugPrint(
      '[TOKEN] saved len=${token.length}, read back len='
      '${(prefs.getString(_key) ?? '').length}',
    );
  }

  /// Drops the token and the logged-in flag; other preferences stay.
  static Future<void> clear() async {
    debugPrint(
      '[TOKEN] CLEARED by:\n'
      '${StackTrace.current.toString().split('\n').skip(1).take(6).join('\n')}',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
    await prefs.setBool('isLoggedIn', false);
    // Logged out means not online: stops the background ride poll too.
    await prefs.setBool('driver_is_online', false);
  }
}
