part of 'package:rider_app/driver_features/parcels/parcel_flow_screen.dart';

class _RouteMap extends StatefulWidget {
  const _RouteMap();

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> with TickerProviderStateMixin {
  // The route is drawn dimmed with a light travelling along it
  // (polyline_animation_plus).
  late final LiveMap _live = LiveMap(vsync: this);
  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _dropIcon;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    final rider = await MapIcons.rider();
    final drop = await MapIcons.drop();
    if (!mounted) return;
    setState(() {
      _riderIcon = rider;
      _dropIcon = drop;
    });
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(28.5692, 77.3242),
        zoom: 15.2,
      ),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _live.attach(controller);
        _live.showAnimatedRoute(
          'parcel',
          _route,
          color: const Color(0xFF2563EB),
        );
      },
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          anchor: const Offset(0.5, 1),
          icon:
              _riderIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('drop'),
          position: _drop,
          anchor: const Offset(0.5, 1),
          icon:
              _dropIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      },
    );
  }
}
