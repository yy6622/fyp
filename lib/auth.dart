import 'package:flutter/material.dart';

import 'bottomNav.dart';
import 'theme.dart';

// ---------------------------------------------------------------------
// Splash / "Loding Page"
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
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

// ---------------------------------------------------------------------
// Shared bits: text field + social login row
// ---------------------------------------------------------------------
class _AuthTextField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final Widget? suffixIcon;
  final TextEditingController? controller;

  const _AuthTextField({
    required this.hint,
    this.obscure = false,
    this.suffixIcon,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

Widget _socialLoginRow(String label) {
  return Column(
    children: [
      Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.primary, thickness: 2, endIndent: 12),
          ),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black)),
          const Expanded(
            child: Divider(color: AppColors.primary, thickness: 2, indent: 12),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _socialIconButton('assets/images/google_icon.png'),
          const SizedBox(width: 16),
          _socialIconButton('assets/images/facebook_icon.png'),
        ],
      ),
    ],
  );
}

Widget _socialIconButton(String asset) {
  return Container(
    width: 50,
    height: 50,
    decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle),
    padding: const EdgeInsets.all(9),
    child: AppImage(asset, fit: BoxFit.contain),
  );
}

// ---------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
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
              _AuthTextField(hint: 'Email'),
              const SizedBox(height: 16),
              _AuthTextField(
                hint: 'Password',
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF9E9E9E),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainPage()),
                    (route) => false,
                  ),
                  child: const Text(
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
              _socialLoginRow('Or Login with'),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Signup
// ---------------------------------------------------------------------
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;
  final _passwordController = TextEditingController();
  String _password = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() => _password = _passwordController.text);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _hasLengthOk => _password.length >= 8 && _password.length <= 12;
  bool get _hasBothCases => _password.contains(RegExp(r'[a-z]')) && _password.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _password.contains(RegExp(r'''[-!@#$%^&*]'''));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: AppImage('assets/images/voya_logo.png', width: 200, height: 200),
              ),
              const SizedBox(height: 12),
              const Text('Sign up an account', style: TextStyle(fontSize: 20, color: Colors.black)),
              const SizedBox(height: 24),
              _AuthTextField(hint: 'Username'),
              const SizedBox(height: 16),
              _AuthTextField(hint: 'Email'),
              const SizedBox(height: 16),
              _AuthTextField(
                hint: 'Password',
                obscure: _obscurePassword,
                controller: _passwordController,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF9E9E9E),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Password must:', style: TextStyle(fontSize: 15, color: Color(0xFF9E9E9E))),
              _passwordRule('Contain 8 to 12 characters', _hasLengthOk),
              _passwordRule('Contain both lower and uppercase letters', _hasBothCases),
              _passwordRule('Contain 1 number', _hasNumber),
              _passwordRule("Contain 1 special character '-!@#\$%^&*'", _hasSpecial),
              const SizedBox(height: 10),
              _AuthTextField(
                hint: 'Confirm Password',
                obscure: _obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF9E9E9E),
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
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
                  onPressed: !_agreeToTerms
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const OtpVerificationPage()),
                          ),
                  child: const Text(
                    'Register',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _socialLoginRow('Or Sign up with'),
            ],
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

// ---------------------------------------------------------------------
// Forgot Password
// ---------------------------------------------------------------------
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
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
              const _AuthTextField(hint: 'Email'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OtpVerificationPage()),
                  ),
                  child: const Text(
                    'Send OTP',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// OTP Verification
// ---------------------------------------------------------------------
class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              const SizedBox(height: 60),
              const Text(
                'OTP Verification',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter the 6-digit verification code sent to your email.',
                style: TextStyle(fontSize: 15, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
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
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  ),
                  child: const Text(
                    'Verify',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A new OTP code has been sent')),
                  ),
                  child: const Text(
                    'Resent OTP',
                    style: TextStyle(
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
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 45,
      height: 60,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
        decoration: InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
