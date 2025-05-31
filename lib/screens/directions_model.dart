import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Directions {
  final LatLngBounds bounds;
  final List<PointLatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;
  final double safetyScore;
  final double lightingScore;
  final double trafficScore;
  final double userRatingScore;

  const Directions({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
    required this.safetyScore,
    required this.lightingScore,
    required this.trafficScore,
    required this.userRatingScore,
  });

  factory Directions.fromMap(
    Map<String, dynamic> map,
    Map<String, dynamic> safetyData,
  ) {
    if ((map['routes'] as List).isEmpty) {
      return Directions(
        bounds: LatLngBounds(northeast: LatLng(0, 0), southwest: LatLng(0, 0)),
        polylinePoints: [],
        totalDistance: '0 km',
        totalDuration: '0 min',
        safetyScore: 5.0,
        lightingScore: 5.0,
        trafficScore: 5.0,
        userRatingScore: 5.0,
      );
    }

    final data = Map<String, dynamic>.from(map['routes'][0]);
    final northeast = data['bounds']['northeast'];
    final southwest = data['bounds']['southwest'];

    String distance = '';
    String duration = '';
    if ((data['legs'] as List).isNotEmpty) {
      final leg = data['legs'][0];
      distance = leg['distance']['text'];
      duration = leg['duration']['text'];
    }

    return Directions(
      bounds: LatLngBounds(
        northeast: LatLng(northeast['lat'], northeast['lng']),
        southwest: LatLng(southwest['lat'], southwest['lng']),
      ),
      polylinePoints: PolylinePoints().decodePolyline(
        data['overview_polyline']['points'],
      ),
      totalDistance: distance,
      totalDuration: duration,
      safetyScore: safetyData['safety'] ?? 5.0,
      lightingScore: safetyData['lighting'] ?? 5.0,
      trafficScore: safetyData['traffic'] ?? 5.0,
      userRatingScore: safetyData['userRating'] ?? 5.0,
    );
  }
}

class DirectionsList {
  final List<Directions> routes;
  final SafetyPreference preference;

  DirectionsList({required this.routes, required this.preference});

  static Future<DirectionsList> fromMapWithTraffic(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> routesWithTraffic,
    SafetyPreference preference,
  ) async {
    final routes = await Future.wait(
      routesWithTraffic.map((routeData) async {
        final route = routeData['route'];
        final trafficData = routeData['trafficData'];

        final safetyData = await _getRouteSafetyData(
          PolylinePoints().decodePolyline(route['overview_polyline']['points']),
          preference,
          trafficData: trafficData,
        );

        return Directions.fromMap({
          'routes': [route],
        }, safetyData);
      }),
    );

    return DirectionsList(routes: routes, preference: preference);
  }

  static Future<Map<String, dynamic>> _getRouteSafetyData(
    List<PointLatLng> points,
    SafetyPreference preference, {
    Map<String, dynamic>? trafficData,
  }) async {
    final double trafficScore = trafficData?['traffic'];

    final lightingScore = 7.5;
    final userRating = 6.5;

    final safetyScore =
        (preference.lightingWeight * lightingScore) +
        (preference.trafficWeight * trafficScore) +
        (preference.userRatingWeight * userRating);

    return {
      'safety': safetyScore,
      'lighting': lightingScore,
      'traffic': trafficScore,
      'userRating': userRating,
    };
  }
}

class SafetyPreference {
  final bool considerLighting;
  final bool considerTraffic;
  final bool considerUserRatings;
  final double lightingWeight;
  final double trafficWeight;
  final double userRatingWeight;

  const SafetyPreference({
    this.considerLighting = true,
    this.considerTraffic = true,
    this.considerUserRatings = true,
    this.lightingWeight = 0.4,
    this.trafficWeight = 0.3,
    this.userRatingWeight = 0.3,
  });
}
