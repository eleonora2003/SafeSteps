import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_login_app/screens/auth_service.dart';
import 'package:google_login_app/screens/login_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:google_login_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

@GenerateNiceMocks([MockSpec<AuthService>(), MockSpec<User>()])
import 'login_screen_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockUser mockUser;

  setUp(() {
    mockAuthService = MockAuthService();
    mockUser = MockUser();
  });

  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
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
        home: LoginScreen(authService: mockAuthService),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SafeSteps'), findsOneWidget);
    expect(find.text('Prijava z Google računom'), findsOneWidget);
  });
}
