import 'package:flutter_test/flutter_test.dart';
import 'package:google_login_app/screens/auth_service.dart';
import 'package:google_login_app/screens/login_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/material.dart';
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
      MaterialApp(home: LoginScreen(authService: mockAuthService)),
    );

    expect(find.text('SafeSteps'), findsOneWidget);
    expect(find.text('Prijava z Google računom'), findsOneWidget);
  });
}
