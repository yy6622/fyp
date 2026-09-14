import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../theme.dart';
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
                          text: const TextSpan(
                            style: TextStyle(fontSize: 15, color: Colors.black),
                            children: [
                              TextSpan(text: 'I agree to the '),
                              TextSpan(text: 'Terms of Use', style: TextStyle(color: Color(0xFF0088FF), fontStyle: FontStyle.italic)),
                              TextSpan(text: ' and '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(color: Color(0xFF0088FF), fontStyle: FontStyle.italic)),
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
                socialLoginRow('Or Sign up with'),
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
