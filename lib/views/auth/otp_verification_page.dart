import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../theme.dart';
import '../onboarding/onboarding_wizard_page.dart';
import 'login_page.dart';

// ---------------------------------------------------------------------
// Email verification status — shown right after Sign Up. Firebase Auth
// verifies an email via a link it sends, not a 6-digit code typed in, so
// this replaces the original 6-box code entry with a status screen
// (Resend + Continue) instead. Continuing doesn't hard-block on
// verification finishing (email delivery timing is out of the app's
// control) — it just lets you know if it hasn't happened yet.
// ---------------------------------------------------------------------
class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final OtpVerificationController controller = OtpVerificationController();

  Future<void> _resend() async {
    await controller.resend();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent')),
    );
  }

  Future<void> _continue() async {
    final verified = await controller.checkVerified();
    if (!mounted) return;
    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not verified yet — you can still continue and verify later")),
      );
    }
    // Onboarding (avatar/phone/region/currency/add friend) runs once right
    // after this, then lands on MainPage itself — see
    // OnboardingWizardPage._finish(). Kept as a plain push (not
    // pushAndRemoveUntil) so the system back button on onboarding's first
    // step just returns here, which is harmless.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingWizardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 60),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to ${controller.email}. Open it, then come back and tap Continue.',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
                    child: const Icon(Icons.mark_email_unread_outlined, size: 42, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: controller.checking ? null : _continue,
                    child: controller.checking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: controller.sending ? null : _resend,
                    child: Text(
                      controller.sending ? 'Sending…' : 'Resend verification email',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF939292),
                        decoration: TextDecoration.underline,
                      ),
                    ),
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
