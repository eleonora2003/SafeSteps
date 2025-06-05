import 'package:dio/dio.dart';
import 'env.dart';
import 'directions_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'osm_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DirectionsRepository {
  static const String _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String _distanceMatrixUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String _roadsApiUrl =
      'https://roads.googleapis.com/v1/snapToRoads';

  final Dio _dio;
  final PolylinePoints _polylinePoints = PolylinePoints();
  final OSMRepository _osmRepository = OSMRepository();

  DirectionsRepository({Dio? dio}) : _dio = dio ?? Dio();

  Future<DirectionsList?> getDirections({
    required LatLng origin,
    required LatLng destination,
    required SafetyPreference preference,
  }) async {
    try {
      final directionsResponse = await _dio.get(
        _directionsBaseUrl,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': googleAPIKey,
          'alternatives': 'true',
          'departure_time': 'now',
          'traffic_model': 'best_guess',
        },
      );

      if (directionsResponse.statusCode != 200) {
        throw Exception(
          'Failed to get directions: ${directionsResponse.statusCode}',
        );
      }

      final routesData = directionsResponse.data['routes'] as List;
      final routesWithTraffic = await Future.wait(
        routesData.map((route) async {
          final points = _polylinePoints.decodePolyline(
            route['overview_polyline']['points'],
          );

          final trafficData = await _getDetailedTrafficData(points);

          return {'route': route, 'trafficData': trafficData};
        }),
      );

      return DirectionsList.fromMapWithTraffic(
        directionsResponse.data,
        routesWithTraffic,
        preference,
      );
    } catch (e) {
      print('Error in getDirections: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getDetailedTrafficData(
    List<PointLatLng> routePoints,
  ) async {
    try {
      // Convert points to string format for Roads API
      final pointsString = routePoints
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');

      final snapResponse = await _dio.get(
        _roadsApiUrl,
        queryParameters: {
          'path': pointsString,
          'interpolate': 'true',
          'key': googleAPIKey,
        },
      );

      if (snapResponse.statusCode != 200) {
        throw Exception('Roads API failed: ${snapResponse.statusCode}');
      }

      final snappedPoints =
          (snapResponse.data['snappedPoints'] as List)
              .map(
                (p) => PointLatLng(
                  p['location']['latitude'],
                  p['location']['longitude'],
                ),
              )
              .toList();

      final sampledPoints = <PointLatLng>[];
      for (int i = 0; i < snappedPoints.length; i += 10) {
        sampledPoints.add(snappedPoints[i]);
      }

      double totalTrafficScore = 0;
      int segmentCount = 0;

      for (int i = 0; i < sampledPoints.length - 1; i++) {
        final origin = sampledPoints[i];
        final destination = sampledPoints[i + 1];

        final trafficResponse = await _dio.get(
          _distanceMatrixUrl,
          queryParameters: {
            'origins': '${origin.latitude},${origin.longitude}',
            'destinations': '${destination.latitude},${destination.longitude}',
            'key': googleAPIKey,
            'departure_time': 'now',
            'traffic_model': 'best_guess',
          },
        );

        if (trafficResponse.statusCode == 200) {
          final element = trafficResponse.data['rows'][0]['elements'][0];
          if (element['status'] == 'OK') {
            final duration = element['duration']['value'];
            final durationInTraffic = element['duration_in_traffic']['value'];
            final delayRatio =
                (durationInTraffic - duration) / (duration > 0 ? duration : 1);

            totalTrafficScore += _calculateTrafficScore(delayRatio);
            segmentCount++;
          }
        }
      }

      double totalLightingScore = 0;
      int lightingPoints = 0;

      for (int i = 0; i < routePoints.length; i += 5) {
        double score = await _osmRepository.getLightingScoreForLocation(
          LatLng(routePoints[i].latitude, routePoints[i].longitude),
        );

        totalLightingScore += score.clamp(1.0, 10.0);
        lightingPoints++;
      }

      double totalUserRating = 0;
      int userRatingPoints = 0;

      for (int i = 0; i < routePoints.length; i += 20) {
        try {
          final placemarks = await geo.placemarkFromCoordinates(
            routePoints[i].latitude,
            routePoints[i].longitude,
          );

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final streetName = extractPureStreetName(
              place.street ?? place.thoroughfare,
            );

            if (streetName.isNotEmpty) {
              final rating = await getStreetRating(streetName);
              totalUserRating += rating;
              userRatingPoints++;
            }
          }
        } catch (e) {
          print('Error getting user rating for point: $e');
        }
      }
      final avgUserRating =
          userRatingPoints > 0 ? totalUserRating / userRatingPoints : 5.0;

      final avgTrafficScore =
          segmentCount > 0 ? totalTrafficScore / segmentCount : 5.0;

      return {
        'traffic': avgTrafficScore,
        'lighting':
            lightingPoints > 0 ? (totalLightingScore / lightingPoints) : 5.0,
        'userRating': avgUserRating,
        'segments_analyzed': segmentCount,
      };
    } catch (e) {
      print('Error in _getDetailedTrafficData: $e');
      return {
        'traffic': 5.0,
        'lighting': 5.0,
        'userRating': 5.0,
        'segments_analyzed': 0,
        'error': e.toString(),
      };
    }
  }

  double _calculateTrafficScore(double delayRatio) {
    if (delayRatio < 0.05) return 10.0;
    if (delayRatio < 0.15) return 8.0;
    if (delayRatio < 0.30) return 6.0;
    if (delayRatio < 0.50) return 4.0;
    if (delayRatio < 0.75) return 2.0;
    return 1.0;
  }

  Future<LatLng?> getLocationFromAddress(String address) async {
    try {
      final locations = await geo.locationFromAddress(address);
      return locations.isNotEmpty
          ? LatLng(locations.first.latitude, locations.first.longitude)
          : null;
    } catch (e) {
      print('Error in getLocationFromAddress: $e');
      rethrow;
    }
  }

  Future<String?> getPlaceName(LatLng position) async {
    try {
      final places = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return places.isNotEmpty
          ? places.first.locality ??
              places.first.subAdministrativeArea ??
              places.first.administrativeArea
          : null;
    } catch (e) {
      print('Error in getPlaceName: $e');
      return null;
    }
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _ratingsCollection = 'ratings';

  static Future<void> saveStreetRating(String fullStreet, int newRating) async {
    try {
      final streetName = extractPureStreetName(fullStreet);
      final docRef = _firestore.collection(_ratingsCollection).doc(streetName);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (doc.exists) {
          final data = doc.data()!;
          final currentAvg = data['averageRating'] ?? 5.0;
          final currentCount = data['count'] ?? 0;
          final currentTotal = data['totalRating'] ?? 0;

          final newCount = currentCount + 1;
          final newTotal = currentTotal + newRating;
          final newAvg = newTotal / newCount;

          transaction.update(docRef, {
            'averageRating': newAvg,
            'count': newCount,
            'totalRating': newTotal,
            'lastUpdated': FieldValue.serverTimestamp(),
            'streetName': streetName,
          });
        } else {
          transaction.set(docRef, {
            'averageRating': newRating.toDouble(),
            'count': 1,
            'totalRating': newRating,
            'streetName': streetName,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to save rating: $e');
    }
  }

  static final Map<String, double> _streetRatingCache = {};

  static Future<double> getStreetRating(String fullStreet) async {
    try {
      final streetName = extractPureStreetName(fullStreet);
      if (streetName.isEmpty) return 5.0;

      print('Fetching rating for street: $streetName');

      final doc =
          await _firestore.collection(_ratingsCollection).doc(streetName).get();

      if (!doc.exists) {
        print('No rating found for street: $streetName, using default 5.0');
        return 5.0;
      }

      final data = doc.data();
      if (data == null) {
        print('Document exists but has no data for street: $streetName');
        return 5.0;
      }

      print('Firestore document data: $data');

      final rating =
          data['averageRating'] ?? data['avgRating'] ?? data['rating'] ?? 5.0;

      final double finalRating =
          (rating is int)
              ? rating.toDouble()
              : (rating is double)
              ? rating
              : 5.0;

      print('Resolved rating for $streetName: $finalRating');
      return finalRating;
    } catch (e) {
      print('Error getting street rating: $e');
      return 5.0;
    }
  }

  static String extractPureStreetName(String? fullStreet) {
    if (fullStreet == null) return 'Unknown Street';

    return fullStreet
        .replaceAll(RegExp(r'\d+.*$'), '')
        .replaceAll(RegExp(r',.*$'), '')
        .trim();
  }
}
