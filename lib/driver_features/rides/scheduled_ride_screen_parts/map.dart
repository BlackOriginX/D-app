part of 'package:rider_app/driver_features/rides/scheduled_ride_screen.dart';

class _Map extends StatefulWidget {
  const _Map();

  @override
  State<_Map> createState() => _MapState();
}

class _MapState extends State<_Map> with TickerProviderStateMixin {
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
        zoom: 14.6,
      ),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _live.attach(controller);
        _live.showAnimatedRoute(
          'scheduled',
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
