import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // 🔥 Inicializacija Firebase-a
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSteps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E7D46),
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF9FEFB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E7D46)),
        useMaterial3: true,
      ),
      home: LoginScreen(),
    );
  }
}
