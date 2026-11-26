import 'package:shared_preferences/shared_preferences.dart';

/// "Zero distraction" switch for THIS app while a ride is in progress.
///
/// The flag lives in SharedPreferences (not in memory) because ride-request
/// alerts are also shown from the background-service isolate and from the
/// Firebase background isolate, which cannot see this isolate's variables.
/// Those isolates call [isActive], which reloads the prefs first.
///
/// What this controls: ride-request alerts, sounds and heads-up popups that
/// the app shows itself. What it cannot control: other apps, calls, SMS, and
/// FCM messages that carry a `notification` block (Android shows those
/// directly without running app code; ask the backend to send data-only
/// messages for ride requests).
class RideDistractionGuard {
  RideDistractionGuard._();

  static const _flagKey = 'ride_in_progress';
  static const _sinceKey = 'ride_in_progress_since';

  /// A flag older than this is treated as stale (the app died mid-ride and
  /// never cleaned up), so alerts can never stay muted forever.
  static const _maxAge = Duration(hours: 12);

  static Future<void> setActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    if (active) {
      await prefs.setBool(_flagKey, true);
      await prefs.setInt(_sinceKey, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_flagKey);
      await prefs.remove(_sinceKey);
    }
  }

  /// True while a ride is in progress. Safe to call from any isolate.
  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // another isolate may have changed it
    if (prefs.getBool(_flagKey) != true) return false;
    final since = prefs.getInt(_sinceKey);
    if (since == null) return true;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(since),
    );
    return age < _maxAge;
  }
}
