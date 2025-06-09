import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_login_app/screens/ratings_pie_chart_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'mocks.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuerySnapshot mockQuerySnapshot;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuerySnapshot = MockQuerySnapshot();

    when(mockFirestore.collection('street_ratings')).thenReturn(mockCollection);
    when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
  });

  testWidgets(
    'RatingsPieChartScreen shows loading indicator when isLoading is true',
    (WidgetTester tester) async {
      when(mockQuerySnapshot.docs).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(home: RatingsPieChartScreen(firestore: mockFirestore)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ni ocenjenih lokacij.'), findsNothing);
      expect(find.byType(PieChart), findsNothing);
    },
  );

  testWidgets(
    'RatingsPieChartScreen shows empty state when no ratings are present',
    (WidgetTester tester) async {
      when(mockQuerySnapshot.docs).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(home: RatingsPieChartScreen(firestore: mockFirestore)),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ni ocenjenih lokacij.'), findsOneWidget);
      expect(find.byType(PieChart), findsNothing);
    },
  );

  testWidgets('RatingsPieChartScreen shows pie chart with correct data', (
    WidgetTester tester,
  ) async {
    // Providing 3 ratings for each category
    final doc1 = MockQueryDocumentSnapshot();
    final doc2 = MockQueryDocumentSnapshot();
    final doc3 = MockQueryDocumentSnapshot();

    when(doc1.get('rating')).thenReturn(8.0);
    when(doc1['rating']).thenReturn(8.0);
    when(doc1.data()).thenReturn({'rating': 8.0});

    when(doc2.get('rating')).thenReturn(5.0);
    when(doc2['rating']).thenReturn(5.0);
    when(doc2.data()).thenReturn({'rating': 5.0});

    when(doc3.get('rating')).thenReturn(2.0);
    when(doc3['rating']).thenReturn(2.0);
    when(doc3.data()).thenReturn({'rating': 2.0});

    when(mockQuerySnapshot.docs).thenReturn([doc1, doc2, doc3]);

    await tester.pumpWidget(
      MaterialApp(home: RatingsPieChartScreen(firestore: mockFirestore)),
    );

    await tester.pump();

    expect(find.byType(PieChart), findsOneWidget);
    final pieChart = tester.widget<PieChart>(find.byType(PieChart));
    expect(pieChart.data.sections.length, 3);
  });

  testWidgets('RatingsPieChartScreen handles mixed ratings correctly', (
    WidgetTester tester,
  ) async {
    final doc1 = MockQueryDocumentSnapshot();
    final doc2 = MockQueryDocumentSnapshot();
    final doc3 = MockQueryDocumentSnapshot();

    when(doc1.get('rating')).thenReturn(8.0);
    when(doc1['rating']).thenReturn(8.0);
    when(doc1.data()).thenReturn({'rating': 8.0});

    when(doc2.get('rating')).thenReturn(5.0);
    when(doc2['rating']).thenReturn(5.0);
    when(doc2.data()).thenReturn({'rating': 5.0});

    when(doc3.get('rating')).thenReturn(2.0);
    when(doc3['rating']).thenReturn(2.0);
    when(doc3.data()).thenReturn({'rating': 2.0});

    when(mockQuerySnapshot.docs).thenReturn([doc1, doc2, doc3]);

    await tester.pumpWidget(
      MaterialApp(home: RatingsPieChartScreen(firestore: mockFirestore)),
    );

    await tester.pump();

    expect(find.byType(PieChart), findsOneWidget);
    final pieChart = tester.widget<PieChart>(find.byType(PieChart));
    expect(pieChart.data.sections.length, 3);
  });

  testWidgets('RatingsPieChartScreen displays correct app bar', (
    WidgetTester tester,
  ) async {
    when(mockQuerySnapshot.docs).thenReturn([]);

    await tester.pumpWidget(
      MaterialApp(home: RatingsPieChartScreen(firestore: mockFirestore)),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Graf ocen'), findsOneWidget);

    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);

    final appBarWidget = tester.widget<AppBar>(appBar);
    expect(appBarWidget.backgroundColor, const Color(0xFF1E7D46));
  });
}
