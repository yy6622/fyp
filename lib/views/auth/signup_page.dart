import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../theme.dart';
import '../onboarding/onboarding_wizard_page.dart';
import '../shared/bottom_nav.dart';
import 'auth_widgets.dart';
import 'otp_verification_page.dart';

// ---------------------------------------------------------------------
// Signup
// ---------------------------------------------------------------------
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final SignupController controller = SignupController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// "Terms of Use"/"Privacy Policy" below used to be plain TextSpans
  /// styled exactly like links (blue, italic) with no TapGestureRecognizer
  /// at all — tapping either did nothing. There's no real legal document
  /// behind either one yet (this is a student FYP project, not a
  /// registered business), so rather than silently doing nothing OR
  /// pretending to open a real document, this shows an honest, clearly
  /// labelled placeholder — same "say so honestly" pattern this app uses
  /// elsewhere for a feature that genuinely isn't built yet (see
  /// EmbassyPage's "not available yet" state for a country with no data).
  void _showLegalPlaceholder(String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
        content: Text(
          'Voya is a student final-year project, not a registered business — there is no real $title document yet. '
          'This screen exists so the checkbox above isn\'t agreeing to nothing.',
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final error = await controller.signUp();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OtpVerificationPage()),
    );
  }

  // The "Register" button below is disabled until Agree to Terms is
  // checked (see its onPressed) — Google sign-up used to skip that
  // requirement entirely, since it called straight into _handleSocial
  // with no gate of its own, letting someone create a
  // full account without ever agreeing to the Terms of Use/Privacy
  // Policy. This is the same gate, applied before the social call runs.
  void _requireAgreement(VoidCallback thenRun) {
    if (!controller.agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Use and Privacy Policy first.')),
      );
      return;
    }
    thenRun();
  }

  // "Sign up with Google" and "Login with Google" are the same Firebase
  // call either way (see _runSocialLogin in
  // auth_controller.dart) — same handling as LoginPage's.
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
                const Text('Sign up an account', style: TextStyle(fontSize: 20, color: Colors.black)),
                const SizedBox(height: 24),
                AuthTextField(hint: 'Username', controller: controller.usernameController),
                const SizedBox(height: 16),
                AuthTextField(hint: 'Email', controller: controller.emailController),
                const SizedBox(height: 16),
                AuthTextField(
                  hint: 'Password',
                  obscure: controller.obscurePassword,
                  controller: controller.passwordController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF9E9E9E),
                    ),
                    onPressed: controller.toggleObscurePassword,
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Password must:', style: TextStyle(fontSize: 15, color: Color(0xFF9E9E9E))),
                _passwordRule('Contain 8 to 12 characters', controller.hasLengthOk),
                _passwordRule('Contain both lower and uppercase letters', controller.hasBothCases),
                _passwordRule('Contain 1 number', controller.hasNumber),
                _passwordRule("Contain 1 special character '-!@#\$%^&*'", controller.hasSpecial),
                const SizedBox(height: 10),
                AuthTextField(
                  hint: 'Confirm Password',
                  obscure: controller.obscureConfirm,
                  controller: controller.confirmController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF9E9E9E),
                    ),
                    onPressed: controller.toggleObscureConfirm,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: controller.agreeToTerms,
                      activeColor: AppColors.primary,
                      onChanged: controller.setAgreeToTerms,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 15, color: Colors.black),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Use',
                                style: const TextStyle(color: Color(0xFF0088FF), fontStyle: FontStyle.italic),
                                recognizer: TapGestureRecognizer()..onTap = () => _showLegalPlaceholder('Terms of Use'),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(color: Color(0xFF0088FF), fontStyle: FontStyle.italic),
                                recognizer: TapGestureRecognizer()..onTap = () => _showLegalPlaceholder('Privacy Policy'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: (!controller.agreeToTerms || controller.loading) ? null : _submit,
                    child: controller.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                socialLoginRow(
                  'Or Sign up with',
                  onGoogle: () => _requireAgreement(() => _handleSocial(controller.signUpWithGoogle)),
                  googleBusy: controller.googleLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordRule(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '${met ? '✓' : '✕'} $label',
        style: TextStyle(fontSize: 13, color: met ? const Color(0xFF03BB00) : Colors.red),
      ),
    );
  }
}
