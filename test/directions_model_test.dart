import 'package:flutter_polyline_points/flutter_polyline_points.dart'
    as polyline;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:google_login_app/screens/directions_model.dart';
import 'mocks.mocks.dart';

void main() {
  group('Directions Model Tests', () {
    late MockPolylinePoints mockPolylinePoints;

    setUp(() {
      mockPolylinePoints = MockPolylinePoints();
    });

    test('Directions.fromMap creates Directions with valid data', () {
      final map = <String, dynamic>{
        'routes': [
          {
            'bounds': {
              'northeast': {'lat': 46.0569, 'lng': 14.5058},
              'southwest': {'lat': 46.0369, 'lng': 14.4858},
            },
            'overview_polyline': {'points': '_p~iF~ps|U'},
            'legs': [
              {
                'distance': {'text': '5 km'},
                'duration': {'text': '10 min'},
              },
            ],
          },
        ],
      };
      final safetyData = <String, dynamic>{
        'safety': 7.0,
        'lighting': 6.0,
        'traffic': 5.0,
        'userRating': 8.0,
        'streetNames': ['Main Street'],
      };

      final polylinePoints = [polyline.PointLatLng(46.0569, 14.5058)];
      when(
        mockPolylinePoints.decodePolyline('_p~iF~ps|U'),
      ).thenReturn(polylinePoints);

      final directions = Directions.fromMap(
        map,
        safetyData,
        TravelMode.driving,
      );

      expect(directions.bounds.northeast.latitude, 46.0569);
      expect(directions.totalDistance, '5 km');
      expect(directions.safetyScore, 7.0);
      expect(directions.streetNames, ['Main Street']);
    });

    test('Directions.fromMap handles empty routes', () {
      final map = <String, dynamic>{'routes': []};
      final safetyData = <String, dynamic>{};

      final directions = Directions.fromMap(
        map,
        safetyData,
        TravelMode.driving,
      );

      expect(directions.polylinePoints, isEmpty);
      expect(directions.totalDistance, '0 km');
      expect(directions.safetyScore, 5.0);
    });
  });
}
