import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'map_screen.dart';
import 'package:google_login_app/main.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends StatelessWidget {
  final AuthService _authService;

  LoginScreen({super.key, AuthService? authService})
    : _authService = authService ?? AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFAF1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D46),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: (locale) {
              MyApp.setLocale(context, locale);
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: Locale('sl'),
                    child: Text('Slovenščina'),
                  ),
                  PopupMenuItem(value: Locale('en'), child: Text('English')),
                ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 60,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'SafeSteps',
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.loginSubtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login, size: 22, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)!.loginButton,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 6,
                    shadowColor: Colors.green.withOpacity(0.3),
                  ),
                  onPressed: () async {
                    User? user = await _authService.signInWithGoogle();
                    if (user != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 30),
                Text(
                  AppLocalizations.of(context)!.loginInfo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
