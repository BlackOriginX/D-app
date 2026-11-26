import 'package:geolocator/geolocator.dart';

import 'tracked_fix.dart';

/// Cleans raw GPS readings so the vehicle does not teleport or spin.
///
///  * drops poor fixes (accuracy worse than [maxAccuracyM]),
///  * drops out-of-order fixes and impossible jumps (> [maxSpeedMps]),
///  * treats tiny movement at low speed as "standing still" (no jitter),
///  * uses the GPS heading when it is trustworthy, else the bearing from the
///    previous point to this one, else the last known bearing.
class RideFixFilter {
  RideFixFilter({
    this.maxAccuracyM = 50,
    this.firstFixAccuracyM = 120,
    this.maxSpeedMps = 70, // 252 km/h
    this.stillSpeedMps = 1.0, // below this the vehicle counts as standing
    this.minMoveM = 4,
    this.resyncAfter = const Duration(seconds: 30),
  });

  final double maxAccuracyM;
  final double firstFixAccuracyM;
  final double maxSpeedMps;
  final double stillSpeedMps;
  final double minMoveM;

  /// After this long without an accepted fix, the next one is trusted even if
  /// it looks like a jump (tunnel, GPS gap).
  final Duration resyncAfter;

  Position? _last;
  double _bearing = 0;

  void reset() {
    _last = null;
    _bearing = 0;
  }

  /// Returns the cleaned fix, or null when [raw] must be ignored.
  TrackedFix? accept(Position raw, {bool simulated = false}) {
    final last = _last;
    final accuracyLimit = last == null ? firstFixAccuracyM : maxAccuracyM;
    if (!simulated && raw.accuracy > accuracyLimit) return null;

    if (last == null) {
      _last = raw;
      _bearing = _validHeading(raw) ?? 0;
      return TrackedFix(
        position: raw,
        bearing: _bearing,
        speedKmh: _kmh(raw.speed),
        stationary: false,
        simulated: simulated,
      );
    }

    final dtMs = raw.timestamp.difference(last.timestamp).inMilliseconds;
    if (dtMs <= 0) return null; // old or duplicate reading
    final dist = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      raw.latitude,
      raw.longitude,
    );
    final dt = dtMs / 1000.0;
    final impliedSpeed = dist / dt;
    if (!simulated &&
        impliedSpeed > maxSpeedMps &&
        raw.timestamp.difference(last.timestamp) < resyncAfter) {
      return null; // teleport
    }

    // Speed: trust the receiver, fall back to distance / time.
    final speed = (raw.speed.isFinite && raw.speed >= 0)
        ? raw.speed
        : impliedSpeed;

    // Standing still: GPS wanders a few metres even when parked. Keep the old
    // spot and bearing so the marker does not shake or spin.
    final jitterRadius = minMoveM > raw.accuracy * 0.5
        ? minMoveM
        : raw.accuracy * 0.5;
    if (speed < stillSpeedMps && dist < jitterRadius) {
      return TrackedFix(
        position: last,
        bearing: _bearing,
        speedKmh: 0,
        stationary: true,
        simulated: simulated,
      );
    }

    // Bearing: GPS heading only when moving fast enough for it to be real.
    double? bearing;
    if (speed >= 1.5) bearing = _validHeading(raw);
    if (bearing == null && dist >= minMoveM) {
      bearing = _normalize(
        Geolocator.bearingBetween(
          last.latitude,
          last.longitude,
          raw.latitude,
          raw.longitude,
        ),
      );
    }
    _bearing = bearing ?? _bearing;
    _last = raw;
    return TrackedFix(
      position: raw,
      bearing: _bearing,
      speedKmh: _kmh(speed),
      stationary: false,
      simulated: simulated,
    );
  }

  /// A heading is only real when it is in range and not the "unknown" 0 / -1.
  double? _validHeading(Position p) {
    final h = p.heading;
    if (!h.isFinite || h <= 0 || h >= 360) return null;
    if (p.headingAccuracy.isFinite &&
        p.headingAccuracy > 0 &&
        p.headingAccuracy > 60) {
      return null;
    }
    return h;
  }

  double _normalize(double deg) {
    if (!deg.isFinite) return _bearing;
    final d = deg % 360;
    return d < 0 ? d + 360 : d;
  }

  int _kmh(double mps) {
    if (!mps.isFinite || mps <= 0.3) return 0;
    return (mps * 3.6).round().clamp(0, 180);
  }
}
