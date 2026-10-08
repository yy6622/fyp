import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../theme.dart';
import '../onboarding/onboarding_wizard_page.dart';
import '../shared/bottom_nav.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

// ---------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LoginController controller = LoginController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = await controller.login();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  Future<void> _handleSocial(Future<SocialLoginOutcome> Function() signIn) async {
    final outcome = await signIn();
    if (!mounted) return;
    switch (outcome.result) {
      case SocialLoginResult.cancelled:
        return;
      case SocialLoginResult.error:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.errorMessage!)));
        return;
      case SocialLoginResult.success:
        if (outcome.isNewUser) {
          // Same destination a brand-new email/password account reaches
          // after verifying — avatar/phone/region/currency/add friend —
          // which itself lands on MainPage when done (see
          // OnboardingWizardPage._finish()). Google/Facebook accounts
          // skip email verification entirely: the provider already
          // vouches for the address.
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingWizardPage()));
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainPage()),
            (route) => false,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: AppImage('assets/images/voya_logo.png', width: 200, height: 200),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Login to your account',
                  style: TextStyle(fontSize: 20, color: Colors.black),
                ),
                const SizedBox(height: 24),
                AuthTextField(hint: 'Email', controller: controller.emailController),
                const SizedBox(height: 16),
                AuthTextField(
                  hint: 'Password',
                  controller: controller.passwordController,
                  obscure: controller.obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF9E9E9E),
                    ),
                    onPressed: controller.toggleObscurePassword,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    ),
                    child: const Text(
                      'Forgot Password ?',
                      style: TextStyle(color: Color(0xFF0015FF), fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: controller.loading ? null : _submit,
                    child: controller.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 15, color: Colors.black)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SignupPage()),
                        ),
                        child: const Text('Sign up', style: TextStyle(fontSize: 15, color: Color(0xFF0015FF))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                socialLoginRow(
                  'Or Login with',
                  onGoogle: () => _handleSocial(controller.loginWithGoogle),
                  onFacebook: () => _handleSocial(controller.loginWithFacebook),
                  googleBusy: controller.googleLoading,
                  facebookBusy: controller.facebookLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
