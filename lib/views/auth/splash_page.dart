import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import 'login_page.dart';
import 'otp_verification_page.dart';

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
      if (AuthService.instance.currentUser == null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }
      // Still signed in: the trusted-device check (FR04) runs again, so a phone
      // whose 30 days have passed asks for a new email code.
      openAppAfterSignIn(context);
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
            const _SplashLoadingBar(),
          ],
        ),
      ),
    );
  }
}
class _SplashLoadingBar extends StatelessWidget {
  const _SplashLoadingBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: const SizedBox(
        width: 139,
        height: 6,
        child: LinearProgressIndicator(
          backgroundColor: Color(0xFFF4F4F4),
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
