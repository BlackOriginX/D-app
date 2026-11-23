import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rider_app/common/theme/torkk_colors.dart';

/// App lock: when "App lock" is on in Settings > Privacy & Security and the
/// driver is logged in, the app asks for Face ID / fingerprint / phone screen
/// lock on every launch, and again when it comes back from the background
/// after [lockAfter].
///
/// Wrap the whole app with it (see `MaterialApp.router(builder: ...)`). While
/// locked, an opaque screen sits over everything so nothing is visible.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  /// How long the app may stay in the background before it asks again.
  static const lockAfter = Duration(seconds: 30);

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _locked = false;
  bool _authenticating = false;
  bool _failed = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `paused` only: the Face ID / system prompt makes the app `inactive`, which
    // must not count as leaving the app.
    if (state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (_authenticating || _locked || since == null) return;
      if (DateTime.now().difference(since) >= AppLockGate.lockAfter) {
        _lockIfNeeded();
      }
    }
  }

  Future<bool> _shouldLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('app_lock_enabled') == true &&
          prefs.getBool('isLoggedIn') == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _lockIfNeeded() async {
    if (!await _shouldLock() || !mounted) return;
    setState(() {
      _locked = true;
      _failed = false;
    });
    await _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    var ok = false;
    try {
      // The phone has no screen lock / biometrics any more: nothing to ask
      // for, so don't trap the driver outside the app.
      if (!await _auth.isDeviceSupported()) {
        ok = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_enabled', false);
      } else {
        ok = await _auth.authenticate(
          localizedReason: 'Unlock Torkk',
          authMessages: const [
            AndroidAuthMessages(
              signInTitle: 'Unlock Torkk',
              biometricHint: 'Use your face or fingerprint',
              biometricNotRecognized: 'Not recognised, try again',
              cancelButton: 'Cancel',
            ),
            IOSAuthMessages(cancelButton: 'Cancel'),
          ],
          options: const AuthenticationOptions(stickyAuth: true),
        );
      }
    } on PlatformException {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _failed = !ok;
      if (ok) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              failed: _failed,
              busy: _authenticating,
              onUnlock: _unlock,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.failed,
    required this.busy,
    required this.onUnlock,
  });

  final bool failed;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.torkk;
    return Material(
      color: colors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 84,
                    height: 84,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.lock_outline_rounded,
                      size: 64,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Torkk is locked',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  failed
                      ? 'Not verified. Please try again.'
                      : 'Verify it\'s you to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: failed ? Colors.red : colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onUnlock,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
