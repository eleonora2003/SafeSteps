import 'package:dio/dio.dart';
import 'env.dart';
import 'directions_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart' as geo;

class DirectionsRepository {
  static const String _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String _distanceMatrixUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String _roadsApiUrl =
      'https://roads.googleapis.com/v1/snapToRoads';

  final Dio _dio;
  final PolylinePoints _polylinePoints = PolylinePoints();

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

      final avgTrafficScore =
          segmentCount > 0 ? totalTrafficScore / segmentCount : 5.0;

      return {'traffic': avgTrafficScore, 'segments_analyzed': segmentCount};
    } catch (e) {
      print('Error in _getDetailedTrafficData: $e');
      return {'traffic': 5.0, 'segments_analyzed': 0, 'error': e.toString()};
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
}
