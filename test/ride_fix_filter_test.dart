import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rider_app/service/ride_tracking/ride_fix_filter.dart';

Position pos(
  double lat,
  double lng,
  int sec, {
  double accuracy = 5,
  double speed = 10,
  double heading = 0,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 1, 1).add(Duration(seconds: sec)),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  test('poor accuracy fix is dropped', () {
    final f = RideFixFilter();
    expect(f.accept(pos(28.0, 77.0, 0)), isNotNull);
    expect(f.accept(pos(28.0001, 77.0, 2, accuracy: 200)), isNull);
  });

  test('teleport is dropped, old timestamp is dropped', () {
    final f = RideFixFilter();
    f.accept(pos(28.0, 77.0, 0));
    expect(f.accept(pos(28.5, 77.0, 2)), isNull); // ~55 km in 2 s
    expect(f.accept(pos(28.0001, 77.0, 0)), isNull); // same time
  });

  test('standing still keeps position and bearing, speed 0', () {
    final f = RideFixFilter();
    f.accept(pos(28.0, 77.0, 0, heading: 90));
    final moving = f.accept(pos(28.0, 77.0005, 5, heading: 90))!;
    final still = f.accept(pos(28.00001, 77.00051, 8, speed: 0.2))!;
    expect(still.stationary, isTrue);
    expect(still.speedKmh, 0);
    expect(still.bearing, moving.bearing);
    expect(still.position.longitude, moving.position.longitude);
  });

  test('bearing falls back to previous->current when heading is 0', () {
    final f = RideFixFilter();
    f.accept(pos(28.0, 77.0, 0));
    final north = f.accept(pos(28.001, 77.0, 5, heading: 0))!;
    expect(north.bearing, closeTo(0, 5).or(closeTo(360, 5)));
    final east = f.accept(pos(28.001, 77.001, 10, heading: 0))!;
    expect(east.bearing, closeTo(90, 5));
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
