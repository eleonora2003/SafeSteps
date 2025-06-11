import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_login_app/main.dart';
import 'package:google_login_app/screens/login_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'firebase_mock.dart';
import 'widget_test.mocks.dart';

@GenerateNiceMocks([MockSpec<LoginScreen>()])
void main() {
  late MockLoginScreen mockLoginScreen;

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
  });

  setUp(() {
    mockLoginScreen = MockLoginScreen();
  });

  testWidgets('MyApp builds MaterialApp with correct configuration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'SafeSteps');

    expect(materialApp.theme?.primaryColor, const Color(0xFF1E7D46));
    expect(materialApp.theme?.textTheme.bodyMedium?.fontFamily, 'Poppins');
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF9FEFB));
    expect(materialApp.theme?.colorScheme?.primary, isNotNull);
    expect(materialApp.theme?.useMaterial3, true);

    expect(materialApp.locale, const Locale('sl'));

    expect(
      materialApp.localizationsDelegates,
      containsAll([
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ]),
    );

    expect(
      materialApp.supportedLocales,
      containsAll([const Locale('sl'), const Locale('en')]),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('MyApp changes locale when setLocale is called', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('sl'));

    MyApp.setLocale(
      tester.element(find.byType(MaterialApp)),
      const Locale('en'),
    );
    await tester.pumpAndSettle();

    final updatedMaterialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(updatedMaterialApp.locale, const Locale('en'));
  });
}
