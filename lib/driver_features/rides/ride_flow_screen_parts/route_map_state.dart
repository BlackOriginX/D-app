part of 'package:rider_app/driver_features/rides/ride_flow_screen.dart';

class _RouteMapState extends State<_RouteMap> with TickerProviderStateMixin {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  StreamSubscription<TrackedFix>? _fixSub;
  LatLng? _driverPosition;

  // The route is drawn dimmed with a light travelling along it
  // (polyline_animation_plus). It follows the real road when it can be found.
  late final LiveMap _live = LiveMap(vsync: this);
  List<LatLng> _route = const [];

  LatLng get _from => widget.pickup;
  LatLng get _to => widget.drop;
  LatLng get _middle => LatLng(
    (_from.latitude + _to.latitude) / 2,
    (_from.longitude + _to.longitude) / 2,
  );

  LatLngBounds get _bounds => LatLngBounds(
    southwest: LatLng(
      _from.latitude < _to.latitude ? _from.latitude : _to.latitude,
      _from.longitude < _to.longitude ? _from.longitude : _to.longitude,
    ),
    northeast: LatLng(
      _from.latitude > _to.latitude ? _from.latitude : _to.latitude,
      _from.longitude > _to.longitude ? _from.longitude : _to.longitude,
    ),
  );

  @override
  void initState() {
    super.initState();
    final tracking = RideTrackingController.instance;
    _driverPosition = tracking.latest?.latLng;
    _fixSub = tracking.fixes.listen(_onTrackedFix);
    _loadMarkers();
    _loadRoute();
  }

  @override
  void dispose() {
    _fixSub?.cancel();
    _live.dispose();
    super.dispose();
  }

  void _onTrackedFix(TrackedFix fix) {
    _driverPosition = fix.latLng;
    final markers = _markers.where((m) => m.markerId.value != 'driver').toSet()
      ..add(
        Marker(
          markerId: const MarkerId('driver'),
          position: fix.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: fix.position.heading.isFinite && fix.position.heading >= 0
              ? fix.position.heading
              : 0,
          zIndexInt: 4,
        ),
      );
    if (!mounted) return;
    setState(() => _markers = markers);
    final controller = _controller;
    if (widget.pipMode && controller != null) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: fix.latLng, zoom: 16),
          ),
        ),
      );
    }
  }

  Future<void> _loadRoute() async {
    final from = _from;
    final to = _to;
    _route = [from, to];
    final road = await RouteService.fetch(from, to);
    if (!mounted || from != _from || to != _to) return;
    setState(() => _route = road);
    _showRoute();
  }

  void _showRoute() {
    _live.showAnimatedRoute(
      'ride',
      _route.length >= 2 ? _route : [_from, _to],
      color: const Color(0xFF4285F4),
      width: 6,
    );
  }

  @override
  void didUpdateWidget(covariant _RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigating == widget.navigating &&
        oldWidget.pipMode == widget.pipMode &&
        oldWidget.vehicleAsset == widget.vehicleAsset &&
        oldWidget.pickup == widget.pickup &&
        oldWidget.drop == widget.drop) {
      return;
    }
    _loadMarkers();
    if (oldWidget.pickup != widget.pickup || oldWidget.drop != widget.drop) {
      _loadRoute();
    }
    _frame();
  }

  Future<void> _loadMarkers() async {
    final pickup = await _vehicleMarker(widget.vehicleAsset);
    final drop = await _redPin();
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: _from,
        icon: pickup,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: _to,
        icon: drop,
        anchor: const Offset(0.5, 1),
        zIndexInt: 2,
      ),
    };
    if (widget.navigating) {
      markers.add(
        Marker(
          markerId: const MarkerId('label'),
          position: _middle,
          icon: await _distanceLabel(widget.distance, widget.duration),
          anchor: const Offset(0.15, 0.85),
          zIndexInt: 3,
        ),
      );
    }
    final driverPosition = _driverPosition;
    if (driverPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 4,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _markers = markers);
  }

  void _frame() {
    final controller = _controller;
    if (controller == null) return;
    final driverPosition = _driverPosition;
    if (widget.pipMode && driverPosition != null) {
      controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: driverPosition, zoom: 16),
        ),
      );
      return;
    }
    controller.moveCamera(CameraUpdate.newLatLngBounds(_bounds, 28));
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.pipMode ? (_driverPosition ?? _middle) : _middle,
        zoom: widget.pipMode ? 16 : 14.6,
      ),
      padding: widget.pipMode
          ? EdgeInsets.zero
          : EdgeInsets.only(top: 64, bottom: widget.navigating ? 130 : 240),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        _live.attach(controller);
        _showRoute();
        WidgetsBinding.instance.addPostFrameCallback((_) => _frame());
      },
      markers: _markers,
    );
  }
}
