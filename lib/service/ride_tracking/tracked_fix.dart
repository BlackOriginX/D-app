import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One cleaned-up location reading during a ride.
///
/// Produced by [RideFixFilter] from a raw GPS (or simulated) [Position].
class TrackedFix {
  const TrackedFix({
    required this.position,
    required this.bearing,
    required this.speedKmh,
    required this.stationary,
    this.simulated = false,
  });

  final Position position;

  /// Direction of travel in degrees (0-360). Never NaN.
  final double bearing;

  /// Speed in km/h, 0 when the vehicle is standing still.
  final int speedKmh;

  /// True when the vehicle is standing (signal, traffic). [position] is then
  /// the last real spot, so the marker does not jitter or spin.
  final bool stationary;

  final bool simulated;

  LatLng get latLng => LatLng(position.latitude, position.longitude);
}
