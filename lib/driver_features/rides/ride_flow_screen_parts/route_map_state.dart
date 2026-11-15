part of 'package:rider_app/driver_features/rides/ride_flow_screen.dart';

class _RouteMapState extends State<_RouteMap> with TickerProviderStateMixin {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};

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
    _loadMarkers();
    _loadRoute();
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
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
    if (!mounted) return;
    setState(() => _markers = markers);
  }

  void _frame() {
    final controller = _controller;
    if (controller == null) return;
    controller.moveCamera(CameraUpdate.newLatLngBounds(_bounds, 28));
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _middle, zoom: 14.6),
      padding: EdgeInsets.only(top: 64, bottom: widget.navigating ? 130 : 240),
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
