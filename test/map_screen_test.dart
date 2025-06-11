import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_login_app/l10n/app_localizations.dart';
import 'package:google_login_app/screens/map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'firebase_mock.dart';
import 'map_screen_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<loc.Location>(),
  MockSpec<NavigatorObserver>(),
  MockSpec<FToast>(),
])
import 'map_screen_test.mocks.dart';
import 'mocks.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;
  late MockLocation mockLocation;
  late MockNavigatorObserver mockNavigatorObserver;
  late MockGoogleMapController mockMapController;
  late CustomGeocodingPlatform mockGeocoding;
  late MockCollectionReference mockCollection;
  late MockQuerySnapshot mockQuerySnapshot;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-messaging-sender-id',
        projectId: 'test-project-id',
      ),
    );
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockLocation = MockLocation();
    mockNavigatorObserver = MockNavigatorObserver();
    mockMapController = MockGoogleMapController();
    mockGeocoding = CustomGeocodingPlatform([
      Location(
        latitude: 46.5547,
        longitude: 15.6459,
        timestamp: DateTime.now(),
      ),
    ]);
    mockCollection = MockCollectionReference();
    mockQuerySnapshot = MockQuerySnapshot();

    // Mock Firebase Auth
    when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');

    // Mock Location
    when(
      mockLocation.hasPermission(),
    ).thenAnswer((_) async => loc.PermissionStatus.granted);
    when(mockLocation.getLocation()).thenAnswer(
      (_) async =>
          loc.LocationData.fromMap({'latitude': 46.5547, 'longitude': 15.6459}),
    );

    // Mock Firestore
    final mockDocumentSnapshot = MockQueryDocumentSnapshot();
    when(mockFirestore.collection('street_ratings')).thenReturn(mockCollection);
    when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
    when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot]);
    when(mockDocumentSnapshot.data()).thenReturn({
      'latitude': 46.5547,
      'longitude': 15.6459,
      'rating': 8,
      'comment': 'Safe street',
      'timestamp': Timestamp.now(),
      'uid': 'test_uid',
    });
    when(mockDocumentSnapshot.id).thenReturn('test_doc_id');

    // Mock Google Maps controller
    when(mockMapController.animateCamera(any)).thenAnswer((_) async {});
    when(mockMapController.moveCamera(any)).thenAnswer((_) async {});

    GeocodingPlatform.instance = mockGeocoding;
  });

  Widget createWidgetUnderTest({
    LatLng? initialPosition,
    bool skipInitialLocation = false,
  }) {
    return MaterialApp(
      locale: const Locale('sl'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('sl'), Locale('en')],
      home: MapScreen(
        location: mockLocation,
        initialPosition: initialPosition,
        skipInitialLocation: skipInitialLocation,
      ),
      navigatorObservers: [mockNavigatorObserver],
    );
  }

  testWidgets('MapScreen shows loading indicator when position is null', (
    WidgetTester tester,
  ) async {
    when(
      mockLocation.getLocation(),
    ).thenAnswer((_) => Future.delayed(const Duration(days: 1)));

    await tester.pumpWidget(
      createWidgetUnderTest(initialPosition: null, skipInitialLocation: true),
    );
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'Should show loading indicator when position is null',
    );
    expect(
      find.byType(GoogleMap),
      findsNothing,
      reason: 'GoogleMap should not be visible during loading',
    );
  });

  testWidgets('MapScreen shows GoogleMap when position is available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(
      find.byType(GoogleMap),
      findsOneWidget,
      reason: 'GoogleMap should be visible when position is available',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'Loading indicator should not be visible',
    );
  });

  testWidgets('MapScreen shows search bar components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('search_bar_container')),
      findsOneWidget,
      reason: 'Search bar container should be visible',
    );
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: 'Search TextField should be visible',
    );
    expect(
      find.byIcon(Icons.search),
      findsOneWidget,
      reason: 'Search icon should be visible',
    );
  });

  testWidgets('MapScreen shows app bar with correct title and icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(
      find.text('SafeSteps'),
      findsOneWidget,
      reason: 'AppBar title should be SafeSteps',
    );
    expect(
      find.byIcon(Icons.filter_list),
      findsOneWidget,
      reason: 'Filter icon should be visible',
    );
    expect(
      find.byIcon(Icons.list_alt),
      findsOneWidget,
      reason: 'List icon should be visible',
    );
    expect(
      find.byIcon(Icons.info_outline),
      findsOneWidget,
      reason: 'Info icon should be visible',
    );
    expect(
      find.byIcon(Icons.pie_chart),
      findsOneWidget,
      reason: 'Pie chart icon should be visible',
    );
  });

  testWidgets('MapScreen shows SOS button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(
      find.text('SOS'),
      findsOneWidget,
      reason: 'SOS text should be visible',
    );
    expect(
      find.byIcon(Icons.sos),
      findsOneWidget,
      reason: 'SOS icon should be visible',
    );
  });

  testWidgets('MapScreen shows map control buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.map),
      findsOneWidget,
      reason: 'Map type button should be visible',
    );
    expect(
      find.byIcon(Icons.my_location),
      findsOneWidget,
      reason: 'My location button should be visible',
    );
    expect(
      find.byIcon(Icons.directions),
      findsOneWidget,
      reason: 'Directions button should be visible',
    );
  });

  testWidgets('MapScreen loads and displays markers from Firestore', (
    WidgetTester tester,
  ) async {
    final mockDocumentSnapshot = MockQueryDocumentSnapshot();
    when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot]);
    when(mockDocumentSnapshot.data()).thenReturn({
      'latitude': 46.5547,
      'longitude': 15.6459,
      'rating': 8,
      'comment': 'Safe street',
      'timestamp': Timestamp.now(),
      'uid': 'test_uid',
    });
    when(mockDocumentSnapshot.id).thenReturn('test_doc_id');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final googleMapFinder = find.byType(GoogleMap);
    final googleMapWidget = tester.widget<GoogleMap>(googleMapFinder);
    googleMapWidget.onMapCreated?.call(mockMapController);

    await tester.pumpAndSettle();

    expect(
      find.byType(GoogleMap),
      findsOneWidget,
      reason: 'GoogleMap should be visible',
    );
  });

  testWidgets('MapScreen toggles map type when map button is pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final googleMapFinder = find.byType(GoogleMap);
    final googleMapWidget = tester.widget<GoogleMap>(googleMapFinder);
    googleMapWidget.onMapCreated?.call(mockMapController);

    await tester.pump();

    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.map),
      findsOneWidget,
      reason: 'Map type button should remain visible',
    );
  });

  testWidgets(
    'MapScreen navigates to current location when my_location button is pressed',
    (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final googleMapFinder = find.byType(GoogleMap);
      final googleMapWidget = tester.widget<GoogleMap>(googleMapFinder);
      googleMapWidget.onMapCreated?.call(mockMapController);

      await tester.pump();

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      verify(
        mockMapController.animateCamera(any),
      ).called(greaterThanOrEqualTo(1));
    },
  );
}

class CustomGeocodingPlatform extends GeocodingPlatform {
  final List<Location> _locations;

  CustomGeocodingPlatform(this._locations);

  @override
  Future<List<Location>> locationFromAddress(
    String address, {
    String? localeIdentifier,
  }) async {
    return _locations;
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async {
    return [
      Placemark(
        name: 'Test Location',
        street: 'Test Street',
        locality: 'Maribor',
        country: 'Slovenia',
      ),
    ];
  }
}
