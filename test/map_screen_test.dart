import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_login_app/screens/map_screen.dart';
import 'all_ratings_screen_test.mocks.dart';
import 'firebase_mock.dart';
import 'map_screen_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<loc.Location>(),
  MockSpec<GoogleMapController>(),
  MockSpec<NavigatorObserver>(),
  MockSpec<FToast>(),
])
void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;
  late MockLocation mockLocation;
  late MockNavigatorObserver mockNavigatorObserver;
  late MockGoogleMapController mockMapController;
  late CustomGeocodingPlatform mockGeocoding;

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

    // Mock Firebase Auth
    when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');

    // Mock Location
    when(
      mockLocation.hasPermission(),
    ).thenAnswer((_) => Future.value(loc.PermissionStatus.granted));
    when(mockLocation.getLocation()).thenAnswer(
      (_) => Future.value(
        loc.LocationData.fromMap({'latitude': 46.5547, 'longitude': 15.6459}),
      ),
    );

    // Mock Firestore
    final mockCollection = MockCollectionReference();
    final mockQuerySnapshot = MockQuerySnapshot();
    final mockDocumentSnapshot = MockQueryDocumentSnapshot();

    when(mockFirestore.collection('street_ratings')).thenReturn(mockCollection);
    when(
      mockCollection.get(),
    ).thenAnswer((_) => Future.value(mockQuerySnapshot));
    when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot]);
    when(mockDocumentSnapshot.data()).thenReturn({
      'latitude': 46.5547,
      'longitude': 15.6459,
      'rating': 8,
      'comment': 'Safe street',
      'timestamp': Timestamp.now(),
      'uid': 'test_uid',
    });

    // Mock Google Maps controller
    when(
      mockMapController.animateCamera(any),
    ).thenAnswer((_) => Future.value());

    GeocodingPlatform.instance = mockGeocoding;
  });

  Widget createWidgetUnderTest({
    LatLng? initialPosition,
    bool skipInitialLocation = false,
  }) {
    return MaterialApp(
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
    ).thenAnswer((_) => Future.delayed(Duration(days: 1)));

    await tester.pumpWidget(
      createWidgetUnderTest(initialPosition: null, skipInitialLocation: true),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
  });

  testWidgets('MapScreen shows GoogleMap when position is available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsOneWidget);
  });

  testWidgets('MapScreen shows search bar components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search_bar_container')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('MapScreen shows app bar with correct title and icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('SafeSteps'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byIcon(Icons.list_alt), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart), findsOneWidget);
  });

  testWidgets('MapScreen shows SOS button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('SOS'), findsOneWidget);
    expect(find.byIcon(Icons.sos), findsOneWidget);
  });

  testWidgets('MapScreen shows map control buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.map), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.directions), findsOneWidget);
  });
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
}
