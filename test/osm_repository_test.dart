import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:google_login_app/screens/osm_repository.dart';
import 'mocks.mocks.dart';

void main() {
  late OSMRepository repository;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    repository = OSMRepository();
  });

  group('OSMRepository Tests', () {
    test('getLightingScoreForLocation calculates score correctly', () async {
      final response = Response(
        data: {
          'elements': [
            {
              'tags': {'lit': 'yes'},
            },
            {
              'tags': {'amenity': 'street_lamp'},
            },
            {
              'tags': {'highway': 'primary'},
            },
            {
              'tags': {'lanes': '2'},
            },
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      when(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).thenAnswer((_) async => response);

      final score = await repository.getLightingScoreForLocation(
        LatLng(46.0569, 14.5058),
      );

      expect(score, greaterThan(5.0));
    });
  });
}
