import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Why tracking is (not) delivering positions. The UI shows a banner for
/// everything except [ok] and [idle].
enum TrackingStatus {
  idle,
  ok,
  gpsOff,
  permissionDenied,
  permissionBlocked, // "Don't ask again": only the phone's Settings can fix it
  backgroundMissing, // only "while in use": stops when the app is minimized
  noSignal, // GPS on, but no fix for a while (tunnel, parking)
}

enum RideLeg { toPickup, toDrop }

/// What the screen, the notification and the (future) bubble show.
class RideProgress {
  const RideProgress({
    this.status = TrackingStatus.idle,
    this.leg = RideLeg.toPickup,
    this.remainingMeters,
    this.etaMinutes,
    this.speedKmh = 0,
    this.moving = false,
    this.customerName = '',
    this.destination,
  });

  final TrackingStatus status;
  final RideLeg leg;
  final double? remainingMeters;
  final int? etaMinutes;
  final int speedKmh;
  final bool moving;
  final String customerName;
  final LatLng? destination;

  bool get active => status != TrackingStatus.idle;

  /// "Head to pickup" / "Head to drop": a clear action, not vague text.
  String get instruction =>
      leg == RideLeg.toPickup ? 'Head to pickup' : 'Head to drop';

  /// "850 m" or "3.2 km".
  String get distanceText {
    final m = remainingMeters;
    if (m == null) return '--';
    if (m < 1000) return '${(m / 10).round() * 10} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  String get etaText {
    final e = etaMinutes;
    if (e == null) return '--';
    return e <= 1 ? '1 min' : '$e min';
  }

  String get speedText => moving ? '$speedKmh km/h' : 'Stopped';

  RideProgress copyWith({
    TrackingStatus? status,
    RideLeg? leg,
    double? remainingMeters,
    int? etaMinutes,
    int? speedKmh,
    bool? moving,
    String? customerName,
    LatLng? destination,
  }) => RideProgress(
    status: status ?? this.status,
    leg: leg ?? this.leg,
    remainingMeters: remainingMeters ?? this.remainingMeters,
    etaMinutes: etaMinutes ?? this.etaMinutes,
    speedKmh: speedKmh ?? this.speedKmh,
    moving: moving ?? this.moving,
    customerName: customerName ?? this.customerName,
    destination: destination ?? this.destination,
  );
}
