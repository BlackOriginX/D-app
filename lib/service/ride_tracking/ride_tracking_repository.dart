import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Where raw positions come from during a ride. The controller only knows this
/// interface, so GPS and the debug simulation are interchangeable.
abstract class RideTrackingRepository {
  /// Raw positions. Must be a fresh stream per call; cancelling the
  /// subscription must release every resource (GPS, timers).
  Stream<Position> positions();

  bool get isSimulated;
}

/// Real GPS through geolocator.
///
/// Android: the process is kept alive by the existing foreground service
/// (RideAlertService), so no second notification is configured here.
/// iOS: background updates need UIBackgroundModes = location in Info.plist.
class GpsTrackingRepository implements RideTrackingRepository {
  const GpsTrackingRepository();

  @override
  bool get isSimulated => false;

  @override
  Stream<Position> positions() {
    final LocationSettings settings;
    if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 2),
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

/// Debug-only: drives along [route] by itself, one point per [tick].
/// The constructor asserts [kDebugMode] so it can never run in a release build.
class SimulatedTrackingRepository implements RideTrackingRepository {
  SimulatedTrackingRepository(
    this.route, {
    this.tick = const Duration(seconds: 1),
    this.targetSeconds = 90,
  }) : assert(kDebugMode, 'Simulation is debug-only');

  final List<LatLng> route;
  final Duration tick;

  /// Roughly how long the whole route takes.
  final int targetSeconds;

  @override
  bool get isSimulated => true;

  @override
  Stream<Position> positions() {
    Timer? timer;
    late final StreamController<Position> controller;
    controller = StreamController<Position>(
      onListen: () {
        if (!kDebugMode || route.length < 2) {
          controller.close();
          return;
        }
        final step = (route.length ~/ targetSeconds).clamp(1, 1000);
        var index = 0;
        timer = Timer.periodic(tick, (t) {
          index += step;
          if (index >= route.length) {
            t.cancel();
            controller.close();
            return;
          }
          final prev = route[index - step];
          final p = route[index];
          final dist = Geolocator.distanceBetween(
            prev.latitude,
            prev.longitude,
            p.latitude,
            p.longitude,
          );
          controller.add(
            Position(
              latitude: p.latitude,
              longitude: p.longitude,
              timestamp: DateTime.now(),
              accuracy: 5,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: Geolocator.bearingBetween(
                prev.latitude,
                prev.longitude,
                p.latitude,
                p.longitude,
              ).abs(),
              headingAccuracy: 0,
              speed: dist / tick.inSeconds.clamp(1, 60),
              speedAccuracy: 0,
            ),
          );
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return controller.stream;
  }
}
