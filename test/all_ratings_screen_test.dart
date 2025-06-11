import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:google_login_app/screens/all_ratings_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

@GenerateMocks(
  [FirebaseAuth, User, FirebaseFirestore],
  customMocks: [
    MockSpec<CollectionReference<Map<String, dynamic>>>(
      as: #MockCollectionReference,
    ),
    MockSpec<Query<Map<String, dynamic>>>(as: #MockQuery),
    MockSpec<QuerySnapshot<Map<String, dynamic>>>(as: #MockQuerySnapshot),
    MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(
      as: #MockQueryDocumentSnapshot,
    ),
  ],
)
import 'all_ratings_screen_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshot;
  late MockQueryDocumentSnapshot mockDoc;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    mockDoc = MockQueryDocumentSnapshot();

    // Mock FirebaseAuth current user
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');

    // Mock Firestore collection and query
    when(mockFirestore.collection('street_ratings')).thenReturn(mockCollection);
    when(
      mockCollection.orderBy('timestamp', descending: true),
    ).thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
  });

  testWidgets('Displays list of ratings after load', (
    WidgetTester tester,
  ) async {
    // Setup mock data
    final mockData = {
      'rating': 5,
      'latitude': 46.0569,
      'longitude': 14.5058,
      'comment': 'Test comment',
      'timestamp': Timestamp.now(),
      'uid': 'test_uid',
    };

    when(mockDoc.data()).thenReturn(mockData);
    when(mockDoc.id).thenReturn('doc1');
    when(mockSnapshot.docs).thenReturn([mockDoc]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sl'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('sl'), Locale('en')],
        home: AllRatingsScreen(firestore: mockFirestore, auth: mockAuth),
      ),
    );

    // Initial loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for data to load
    await tester.pumpAndSettle();

    // Verify the content is displayed
    expect(find.text('Ocena: 5'), findsOneWidget);
    expect(find.text('Komentar: Test comment'), findsOneWidget);
    expect(find.text('Koordinate: (46.0569, 14.5058)'), findsOneWidget);
  });
}
