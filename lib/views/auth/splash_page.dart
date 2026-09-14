import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/bottom_nav.dart';
import 'login_page.dart';

// ---------------------------------------------------------------------
// Splash / "Loding Page" — after the brand beat, routes straight to
// MainPage if a Firebase session is already active, otherwise to Login.
// ---------------------------------------------------------------------
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final signedIn = AuthService.instance.currentUser != null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => signedIn ? const MainPage() : const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppImage('assets/images/voya_logo.png', width: 250, height: 250),
            const SizedBox(height: 24),
            const Text(
              'Plan together.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const Text(
              'Travel better.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 40),
            Container(
              width: 139,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
