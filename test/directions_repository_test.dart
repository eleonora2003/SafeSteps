import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:google_login_app/screens/directions_model.dart';
import 'package:google_login_app/screens/directions_repository.dart';
import 'mocks.mocks.dart';

void main() {
  late DirectionsRepository repository;
  late MockDio mockDio;
  late MockFirebaseFirestore mockFirestore;
  late MockDocumentSnapshot mockDocumentSnapshot;
  late MockDocumentReference mockDocumentReference;
  late MockCollectionReference mockCollectionReference;

  setUp(() {
    mockDio = MockDio();
    mockFirestore = MockFirebaseFirestore();
    mockDocumentSnapshot = MockDocumentSnapshot();
    mockDocumentReference = MockDocumentReference();
    mockCollectionReference = MockCollectionReference();
    repository = DirectionsRepository(dio: mockDio);
  });

  group('DirectionsRepository Tests', () {
    test('getDirections returns DirectionsList for valid response', () async {
      final response = Response(
        data: {
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
                  'steps': [
                    {
                      'start_location': {'lat': 46.0569, 'lng': 14.5058},
                      'end_location': {'lat': 46.0369, 'lng': 14.4858},
                      'polyline': {'points': '_p~iF~ps|U'},
                      'html_instructions': 'Turn left onto Ruška cesta',
                      'maneuver': 'turn-left',
                    },
                  ],
                },
              ],
            },
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      when(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).thenAnswer((_) async => response);

      // Mock snapToRoads API
      when(
        mockDio.get(
          'https://roads.googleapis.com/v1/snapToRoads',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'snappedPoints': [
              {
                'location': {'latitude': 46.0569, 'longitude': 14.5058},
              },
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Mock distanceMatrix API
      when(
        mockDio.get(
          'https://maps.googleapis.com/maps/api/distancematrix/json',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'rows': [
              {
                'elements': [
                  {
                    'status': 'OK',
                    'duration': {'value': 600},
                    'duration_in_traffic': {'value': 660},
                  },
                ],
              },
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Mock Overpass API
      when(
        mockDio.get(
          'https://overpass-api.de/api/interpreter',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'elements': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Mock Firestore for street ratings
      when(
        mockFirestore.collection('ratings'),
      ).thenReturn(mockCollectionReference);
      when(mockCollectionReference.doc(any)).thenReturn(mockDocumentReference);
      when(
        mockDocumentReference.get(),
      ).thenAnswer((_) async => mockDocumentSnapshot);
      when(mockDocumentSnapshot.exists).thenReturn(true);
      when(mockDocumentSnapshot.data()).thenReturn({'averageRating': 5.0});

      final directionsList = await repository.getDirections(
        origin: LatLng(46.0569, 14.5058),
        destination: LatLng(46.0369, 14.4858),
        preference: SafetyPreference(),
        travelMode: TravelMode.driving,
      );

      expect(directionsList, isA<DirectionsList>());
      expect(directionsList!.routes.length, 1);
    });

    test('getStreetRating returns rating from Firestore', () async {
      when(
        mockFirestore.collection('ratings'),
      ).thenReturn(mockCollectionReference);
      when(
        mockCollectionReference.doc('Ruška cesta'),
      ).thenReturn(mockDocumentReference);
      when(
        mockDocumentReference.get(),
      ).thenAnswer((_) async => mockDocumentSnapshot);
      when(mockDocumentSnapshot.exists).thenReturn(true);
      when(mockDocumentSnapshot.data()).thenReturn({'averageRating': 5.0});

      final rating = await DirectionsRepository.getStreetRating('Ruška cesta');

      expect(rating, 5.0);
    });
  });
}
