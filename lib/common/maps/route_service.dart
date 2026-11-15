import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:polyline_animation_plus/polyline_animation_plus.dart';

import 'package:rider_app/common/constants/app_urls.dart';

/// Road route between two points (OSRM), for maps that only preview a trip.
/// Falls back to a straight line when the route cannot be fetched.
class RouteService {
  RouteService._();

  static Future<List<LatLng>> fetch(LatLng from, LatLng to) async {
    final straight = [from, to];
    try {
      final url = Uri.parse(
        AppUrls.osrmRoute(
          originLat: from.latitude,
          originLng: from.longitude,
          destLat: to.latitude,
          destLng: to.longitude,
        ),
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return straight;
      final data = json.decode(response.body);
      final routes = data is Map ? data['routes'] : null;
      if (routes is! List || routes.isEmpty) return straight;
      final geometry = routes.first['geometry'];
      if (geometry is! String) return straight;
      final points = PolylineCodec.decode(geometry);
      return points.length >= 2 ? points : straight;
    } catch (e) {
      debugPrint('[ROUTE] could not fetch the road route: $e');
      return straight;
    }
  }
}
