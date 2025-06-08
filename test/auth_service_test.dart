import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_login_app/screens/auth_service.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<GoogleSignIn>(),
  MockSpec<GoogleSignInAccount>(),
  MockSpec<GoogleSignInAuthentication>(),
  MockSpec<UserCredential>(),
  MockSpec<User>(),
])
import 'auth_service_test.mocks.dart';

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleUser;
  late MockGoogleSignInAuthentication mockGoogleAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleUser = MockGoogleSignInAccount();
    mockGoogleAuth = MockGoogleSignInAuthentication();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    authService = AuthService(auth: mockAuth, googleSignIn: mockGoogleSignIn);
  });

  test('signInWithGoogle returns user on success', () async {
    // 1. Setup Google Sign-In mocks
    when(mockGoogleSignIn.signOut()).thenAnswer((_) => Future.value());
    when(
      mockGoogleSignIn.signIn(),
    ).thenAnswer((_) => Future.value(mockGoogleUser));
    when(
      mockGoogleUser.authentication,
    ).thenAnswer((_) => Future.value(mockGoogleAuth));
    when(mockGoogleAuth.accessToken).thenReturn('access_token');
    when(mockGoogleAuth.idToken).thenReturn('id_token');

    // 2. Setup Firebase Auth mocks
    when(mockAuth.signInWithCredential(any)).thenAnswer((invocation) async {
      // Get the credential from the invocation
      final credential = invocation.positionalArguments[0] as OAuthCredential;
      expect(credential.accessToken, 'access_token');
      expect(credential.idToken, 'id_token');
      return mockUserCredential;
    });

    when(mockUserCredential.user).thenReturn(mockUser);

    // 3. Test the method
    final user = await authService.signInWithGoogle();

    // 4. Verify
    expect(user, mockUser);
    verify(mockAuth.signInWithCredential(any)).called(1);
  });
}
