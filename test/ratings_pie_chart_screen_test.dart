import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_login_app/screens/ratings_pie_chart_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate, // Added Cupertino delegate
          ],
          supportedLocales: const [Locale('sl')],
          home: Builder(
            builder:
                (context) => RatingsPieChartScreen(firestore: mockFirestore),
          ),
        ),
      );

      // Pump without settling to catch initial loading state
      await tester.pump(Duration.zero);

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
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('sl')],
          home: Builder(
            builder:
                (context) => RatingsPieChartScreen(firestore: mockFirestore),
          ),
        ),
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
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('sl')],
        home: Builder(
          builder: (context) => RatingsPieChartScreen(firestore: mockFirestore),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
    final pieChart = tester.widget<PieChart>(find.byType(PieChart));
    expect(pieChart.data.sections.length, 3);

    // Verify section values
    expect(pieChart.data.sections[0].value, 1.0); // Safe (rating >= 7)
    expect(pieChart.data.sections[1].value, 1.0); // Medium (rating >= 4)
    expect(pieChart.data.sections[2].value, 1.0); // Dangerous (rating < 4)

    // Verify section percentages
    expect(pieChart.data.sections[0].title, '33.3%');
    expect(pieChart.data.sections[1].title, '33.3%');
    expect(pieChart.data.sections[2].title, '33.3%');

    // Verify legend labels
    expect(find.text('Varno'), findsOneWidget);
    expect(find.text('Srednje'), findsOneWidget);
    expect(find.text('Nevarno'), findsOneWidget);
  });

  testWidgets('RatingsPieChartScreen displays correct app bar', (
    WidgetTester tester,
  ) async {
    when(mockQuerySnapshot.docs).thenReturn([]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('sl')],
        home: Builder(
          builder: (context) => RatingsPieChartScreen(firestore: mockFirestore),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Graf ocen'), findsOneWidget);

    final appBar = find.byType(AppBar);
    final appBarWidget = tester.widget<AppBar>(appBar);
    expect(appBarWidget.backgroundColor, const Color(0xFF1E7D46));
  });
}

// Mock AppLocalizations for testing
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['sl'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String get chartTitle => 'Graf ocen';
  String get noRatings => 'Ni ocenjenih lokacij.';
  String get chartSubtitle => 'Porazdelitev ocen';
  String get safeChart => 'Varno';
  String get mediumChart => 'Srednje';
  String get dangerChart => 'Nevarno';
}
