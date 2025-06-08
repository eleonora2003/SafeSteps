// test/firebase_mock.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// This is the proper way to mock Firebase without violating platform interface rules
class TestFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return TestFirebaseAppPlatform(
      name,
      const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-messaging-sender-id',
        projectId: 'test-project-id',
      ),
    );
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return TestFirebaseAppPlatform(
      name ?? defaultFirebaseAppName,
      options ??
          const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: 'test-app-id',
            messagingSenderId: 'test-messaging-sender-id',
            projectId: 'test-project-id',
          ),
    );
  }
}

class TestFirebaseAppPlatform extends FirebaseAppPlatform {
  TestFirebaseAppPlatform(super.name, super.options);
}

void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Firebase.delegatePackingProperty = TestFirebasePlatform();
}
