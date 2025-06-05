import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'directions_repository.dart';
import 'package:geocoding/geocoding.dart' as geo;

class Directions {
  final LatLngBounds bounds;
  final List<PointLatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;
  final double safetyScore;
  final double lightingScore;
  final double trafficScore;
  final double userRatingScore;
  final List<String> streetNames;
  final TravelMode travelMode;

  const Directions({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
    required this.safetyScore,
    required this.lightingScore,
    required this.trafficScore,
    required this.userRatingScore,
    this.streetNames = const [],
    this.travelMode = TravelMode.driving,
  });

  factory Directions.fromMap(
    Map<String, dynamic> map,
    Map<String, dynamic> safetyData,
    TravelMode travelMode,
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
        travelMode: travelMode,
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
      streetNames: safetyData['streetNames'] ?? [],
      travelMode: travelMode,
    );
  }
}

class DirectionsList {
  final List<Directions> routes;
  final SafetyPreference preference;
  final TravelMode travelMode;

  DirectionsList({
    required this.routes,
    required this.preference,
    required this.travelMode,
  });

  static Future<DirectionsList> fromMapWithSafetyData(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> routesWithSafetyData,
    SafetyPreference preference,
    TravelMode travelMode,
  ) async {
    final routes = await Future.wait(
      routesWithSafetyData.map((routeData) async {
        final route = routeData['route'];
        final safetyData = routeData['safetyData'];

        return Directions.fromMap(
          {
            'routes': [route],
          },
          safetyData,
          travelMode,
        );
      }),
    );

    return DirectionsList(
      routes: routes,
      preference: preference,
      travelMode: travelMode,
    );
  }

  static Future<Map<String, dynamic>> _getRouteSafetyData(
    List<PointLatLng> points,
    SafetyPreference preference, {
    Map<String, dynamic>? trafficData,
    required TravelMode travelMode,
  }) async {
    double trafficScore = trafficData?['traffic'] ?? 5.0;
    double lightingScore = trafficData?['lighting'] ?? 5.0;

    if (travelMode == TravelMode.walking) {
      trafficScore = 5.0;
    }

    double userRating = 5.0;
    try {
      final streetNames = await _getStreetNamesForRoute(points);
      if (streetNames.isNotEmpty) {
        final uniqueStreetNames = streetNames.toSet().toList();

        final ratings = await Future.wait(
          uniqueStreetNames.map(
            (name) => DirectionsRepository.getStreetRating(name),
          ),
        );

        userRating = ratings.reduce((a, b) => a + b) / ratings.length;
      }
    } catch (e) {
      print('Error getting user ratings: $e');
      userRating = 5.0;
    }

    final safetyScore =
        (preference.considerTraffic && travelMode == TravelMode.driving
            ? preference.trafficWeight * trafficScore
            : 0) +
        (preference.considerLighting
            ? preference.lightingWeight * lightingScore
            : 0) +
        (preference.considerUserRatings
            ? preference.userRatingWeight * userRating
            : 0);

    return {
      'safety': safetyScore,
      'lighting': lightingScore,
      'traffic': trafficScore,
      'userRating': userRating,
      'streetNames': await _getStreetNamesForRoute(points),
    };
  }

  static Future<List<String>> _getStreetNamesForRoute(
    List<PointLatLng> points,
  ) async {
    final streetNames = <String>{};
    final geocoding = geo.GeocodingPlatform.instance;
    if (geocoding == null) return [];

    try {
      for (int i = 0; i < points.length; i += 20) {
        final point = points[i];
        final placemarks = await geocoding.placemarkFromCoordinates(
          point.latitude,
          point.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final streetName = DirectionsRepository.extractPureStreetName(
            place.street ?? place.thoroughfare,
          );

          if (streetName.isNotEmpty) {
            streetNames.add(streetName);
          }
        }
        if (i % 60 == 0) await Future.delayed(Duration(milliseconds: 200));
      }
    } catch (e) {
      print('Error getting street names: $e');
    }

    return streetNames.toList();
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

enum TravelMode { driving, walking }
