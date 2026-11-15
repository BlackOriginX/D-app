import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

/// Ola / Uber style motion for a Google map, built on polyline_animation_plus:
///  * the driver marker glides between GPS positions and turns to face the
///    way it moves,
///  * the route is drawn as "already travelled" and "still to go",
///  * the camera can follow the driver,
///  * a route can be shown with a light travelling along it.
///
/// Create one per map screen, call [attach] from `GoogleMap.onMapCreated`,
/// pass [onCameraMoveStarted] to `GoogleMap.onCameraMoveStarted`, and call
/// [dispose] in the screen's `dispose`.
///
/// The controller draws the driver marker (id `driver`) and the route
/// polylines itself. Do not use those ids in the `GoogleMap` widget's own
/// `markers` / `polylines`.
class LiveMap {
  LiveMap({required this.vsync, this.driverIcon});

  final TickerProvider vsync;

  /// Picture of the driver marker. May be set after [attach].
  BitmapDescriptor? driverIcon;

  static const MarkerId driverId = MarkerId('driver');

  MapAnimationController? _controller;
  bool _driverOnMap = false;
  bool _tracking = false;

  bool get isAttached => _controller != null;

  /// Starts the animation controller for the map that was just created.
  /// [driverAt] puts the driver marker on the map straight away.
  void attach(GoogleMapController map, {LatLng? driverAt}) {
    _controller?.dispose();
    _driverOnMap = driverAt != null;
    _tracking = false;
    _controller = MapAnimationController(
      mapId: map.mapId,
      vsync: vsync,
      // Live GPS: always go to the newest position, over about the time
      // between two updates (up to 5 seconds).
      markerAnimationMode: MarkerAnimationMode.latestOnly,
      markerDuration: const MarkerDuration.adaptive(max: Duration(seconds: 5)),
      markers: driverAt == null
          ? const {}
          : {Marker(markerId: driverId, position: driverAt)},
      markerFrameBuilder: (marker) {
        if (marker.markerId != driverId) return marker;
        return marker.copyWith(
          iconParam: driverIcon,
          anchorParam: const Offset(0.5, 0.5),
          flatParam: true,
          zIndexIntParam: 5,
        );
      },
    );
  }

  /// A new GPS position. The marker glides there (along the route when one is
  /// being tracked).
  void moveDriver(LatLng position) {
    final controller = _controller;
    if (controller == null) return;
    if (_tracking) {
      controller.updateVehicle(position, markerId: driverId);
      return;
    }
    controller.updateMarkers({Marker(markerId: driverId, position: position)});
    _driverOnMap = true;
  }

  /// Draws [route] with the driver following it: the part already travelled is
  /// hidden (or [traveledColor]) and the rest is drawn in [color].
  void trackRoute(
    List<LatLng> route, {
    required Color color,
    Color? traveledColor,
    int width = 6,
    void Function(LatLng position)? onOffRoute,
  }) {
    final controller = _controller;
    if (controller == null || route.length < 2) return;
    controller.trackVehicle(
      VehicleTracking(
        markerId: driverId,
        route: route,
        traveled: RouteStyle(
          color: traveledColor ?? color,
          width: width,
          visible: traveledColor != null,
        ),
        remaining: RouteStyle(color: color, width: width),
        followRoute: true,
        snapToleranceMeters: 50,
        onOffRoute: onOffRoute,
      ),
    );
    _tracking = true;
    _driverOnMap = true;
  }

  /// Stops following the route (the marker stays where it is).
  void stopRoute() {
    if (!_tracking) return;
    _controller?.stopTrackingVehicle(driverId);
    _tracking = false;
  }

  /// Camera follows the driver marker, tilted and turning with the vehicle.
  void follow({
    double zoom = 17,
    double tilt = 35,
    bool turnWithVehicle = true,
    VoidCallback? onStopped,
  }) {
    if (!_driverOnMap) return;
    _controller?.followCamera(
      CameraFollow(
        markerId: driverId,
        zoom: zoom,
        tilt: tilt,
        bearing: turnWithVehicle ? CameraBearing.vehicle : CameraBearing.north,
        onFollowStopped: onStopped,
      ),
    );
  }

  void stopFollowing() => _controller?.stopFollowingCamera();

  /// Pass to `GoogleMap.onCameraMoveStarted` so following stops when the
  /// driver drags the map.
  void onCameraMoveStarted() => _controller?.onCameraMoveStarted();

  /// A route preview: the line is drawn dimmed and a light keeps travelling
  /// along it. Use for maps that show a route without live movement.
  void showAnimatedRoute(
    String id,
    List<LatLng> points, {
    required Color color,
    int width = 5,
  }) {
    final controller = _controller;
    if (controller == null || points.length < 2) return;
    controller.updatePolylines({
      AnimatedPolyline(
        polyline: Polyline(
          polylineId: PolylineId(id),
          color: color,
          width: width,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          points: MapAnimationUtils.generateEquidistantPolylineByDuration(
            path: points,
            duration: const Duration(milliseconds: 2400),
          ),
        ),
        polylineAnimator: const PulseAnimator(
          duration: Duration(milliseconds: 2400),
          baseOpacity: 0.55,
        ),
      ),
    });
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
