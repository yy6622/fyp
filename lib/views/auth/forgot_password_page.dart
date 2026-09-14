import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../theme.dart';
import 'auth_widgets.dart';

// ---------------------------------------------------------------------
// Forgot Password — sends a real Firebase password-reset email. Firebase
// resets passwords via a link it emails, not an in-app code, so this no
// longer hands off to the OTP screen; it shows a "check your email"
// confirmation and returns to Login instead.
// ---------------------------------------------------------------------
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final ForgotPasswordController controller = ForgotPasswordController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = await controller.sendResetLink();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 40),
        title: const Text('Check your email', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text(
          "We've sent a password reset link to your email. Follow the link to set a new password, then come back and log in.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Login', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 100),
                const Text(
                  'Forgot Password ?',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your registered email address to receive a password reset link.',
                  style: TextStyle(fontSize: 15, color: Colors.black),
                ),
                const SizedBox(height: 32),
                AuthTextField(hint: 'Email', controller: controller.emailController),
                const SizedBox(height: 32),
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
                            'Send Reset Link',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
