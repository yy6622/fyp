import 'package:flutter/material.dart';

import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// Controller for [LoginPage].
class LoginController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  bool _loading = false;
  bool get loading => _loading;

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) return 'Enter your email and password.';
    _loading = true;
    notifyListeners();
    try {
      await AuthService.instance.signIn(email: email, password: password);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

/// Controller for [SignupPage].
class SignupController extends ChangeNotifier {
  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  bool _obscureConfirm = true;
  bool get obscureConfirm => _obscureConfirm;

  bool _agreeToTerms = false;
  bool get agreeToTerms => _agreeToTerms;

  bool _loading = false;
  bool get loading => _loading;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  String _password = '';

  SignupController() {
    passwordController.addListener(() {
      _password = passwordController.text;
      notifyListeners();
    });
  }

  bool get hasLengthOk => _password.length >= 8 && _password.length <= 12;
  bool get hasBothCases => _password.contains(RegExp(r'[a-z]')) && _password.contains(RegExp(r'[A-Z]'));
  bool get hasNumber => _password.contains(RegExp(r'[0-9]'));
  bool get hasSpecial => _password.contains(RegExp(r'''[-!@#$%^&*]'''));
  bool get isPasswordValid => hasLengthOk && hasBothCases && hasNumber && hasSpecial;

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleObscureConfirm() {
    _obscureConfirm = !_obscureConfirm;
    notifyListeners();
  }

  void setAgreeToTerms(bool? v) {
    _agreeToTerms = v ?? false;
    notifyListeners();
  }

  /// Creates the Firebase account + Firestore profile doc, and kicks off
  /// email verification. Returns null on success, or a message to show.
  Future<String?> signUp() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;
    if (username.isEmpty) return 'Enter a username.';
    if (email.isEmpty) return 'Enter your email.';
    if (!isPasswordValid) return 'Password does not meet the requirements above.';
    if (password != confirm) return 'Passwords do not match.';

    _loading = true;
    notifyListeners();
    try {
      final user = await AuthService.instance.signUp(email: email, password: password);
      await UserRepository.instance.createProfile(uid: user.uid, name: username, email: email);
      await AuthService.instance.sendEmailVerification();
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }
}

/// Controller for [ForgotPasswordPage].
class ForgotPasswordController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();

  bool _loading = false;
  bool get loading => _loading;

  /// Returns null on success, or a message to show.
  Future<String?> sendResetLink() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return 'Enter your registered email address.';
    _loading = true;
    notifyListeners();
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}

/// Controller for [OtpVerificationPage] — repurposed as an email
/// verification status screen. Firebase Auth verifies an email via a link
/// it sends, not a code the user types in, so there's no 6-digit code to
/// collect here (see the view for what changed and why).
class OtpVerificationController extends ChangeNotifier {
  bool _sending = false;
  bool get sending => _sending;

  bool _checking = false;
  bool get checking => _checking;

  String get email => AuthService.instance.currentUser?.email ?? 'your email';

  Future<void> resend() async {
    _sending = true;
    notifyListeners();
    try {
      await AuthService.instance.sendEmailVerification();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<bool> checkVerified() async {
    _checking = true;
    notifyListeners();
    try {
      return await AuthService.instance.reloadAndCheckVerified();
    } finally {
      _checking = false;
      notifyListeners();
    }
  }
}
