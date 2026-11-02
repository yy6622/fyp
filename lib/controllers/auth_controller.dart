import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/verification_service.dart';

enum SocialLoginResult { cancelled, success, error }

const String suspendedMessage = 'This account has been suspended. Please contact Voya support.';

class SocialLoginOutcome {
  final SocialLoginResult result;
  final bool isNewUser;
  final String? errorMessage;
  const SocialLoginOutcome({required this.result, this.isNewUser = false, this.errorMessage});
}

Future<SocialLoginOutcome> _runSocialLogin(Future<UserCredential?> Function() signIn) async {
  try {
    final cred = await signIn();
    final user = cred?.user;
    if (user == null) return const SocialLoginOutcome(result: SocialLoginResult.cancelled);
    final existing = await UserRepository.instance.fetchProfile(user.uid);
    if (existing != null && await UserRepository.instance.isSuspended(user.uid)) {
      await AuthService.instance.signOut();
      return const SocialLoginOutcome(result: SocialLoginResult.error, errorMessage: suspendedMessage);
    }
    if (existing != null) return const SocialLoginOutcome(result: SocialLoginResult.success, isNewUser: false);
    final name = (user.displayName ?? '').trim();
    await UserRepository.instance.createProfile(
      uid: user.uid,
      name: name.isEmpty ? 'Traveller' : name,
      email: user.email ?? '',
    );
    return const SocialLoginOutcome(result: SocialLoginResult.success, isNewUser: true);
  } on AuthFailure catch (e) {
    return SocialLoginOutcome(result: SocialLoginResult.error, errorMessage: e.message);
  } catch (_) {
    return const SocialLoginOutcome(result: SocialLoginResult.error, errorMessage: 'Something went wrong. Please try again.');
  }
}

/// Controller for [LoginPage].
class LoginController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  bool _loading = false;
  bool get loading => _loading;

  bool _googleLoading = false;
  bool get googleLoading => _googleLoading;

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  Future<String?> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) return 'Enter your email and password.';
    _loading = true;
    notifyListeners();
    try {
      final user = await AuthService.instance.signIn(email: email, password: password);
      // FR96: an account the admin suspended cannot sign in.
      if (await UserRepository.instance.isSuspended(user.uid)) {
        await AuthService.instance.signOut();
        return suspendedMessage;
      }
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

  Future<SocialLoginOutcome> loginWithGoogle() async {
    _googleLoading = true;
    notifyListeners();
    final outcome = await _runSocialLogin(AuthService.instance.signInWithGoogle);
    _googleLoading = false;
    notifyListeners();
    return outcome;
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

  bool _googleLoading = false;
  bool get googleLoading => _googleLoading;

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
      // The 6-digit email code is sent by VerificationCodePage (FR04).
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

  Future<SocialLoginOutcome> signUpWithGoogle() async {
    _googleLoading = true;
    notifyListeners();
    final outcome = await _runSocialLogin(AuthService.instance.signInWithGoogle);
    _googleLoading = false;
    notifyListeners();
    return outcome;
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

/// Controller for [VerificationCodePage]: sends the 6-digit email code,
/// counts down before it can be re-sent, and checks what the traveller typed.
class VerificationCodeController extends ChangeNotifier {
  final CodePurpose purpose;
  VerificationCodeController(this.purpose);

  final TextEditingController codeController = TextEditingController();

  bool _sending = false;
  bool get sending => _sending;

  bool _checking = false;
  bool get checking => _checking;

  String? _error;
  String? get error => _error;

  int _resendIn = 0;
  int get resendIn => _resendIn;
  Timer? _timer;

  String get email => AuthService.instance.currentUser?.email ?? 'your email';

  /// Sends a code. Returns an error message, or null when the email went out.
  Future<String?> send() async {
    if (_sending || _resendIn > 0) return null;
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      await VerificationService.instance.sendCode(purpose);
      _startCountdown(60);
      return null;
    } on VerificationException catch (e) {
      final wait = RegExp(r'(\d+) s').firstMatch(e.message);
      if (wait != null) _startCountdown(int.parse(wait.group(1)!));
      _error = e.message;
      return e.message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _resendIn = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _resendIn = _resendIn > 0 ? _resendIn - 1 : 0;
      if (_resendIn == 0) t.cancel();
      notifyListeners();
    });
  }

  /// True when the code was right.
  Future<bool> verify() async {
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _error = 'Enter the 6-digit code from the email.';
      notifyListeners();
      return false;
    }
    _checking = true;
    _error = null;
    notifyListeners();
    try {
      await VerificationService.instance.verifyCode(purpose, code);
      return true;
    } on VerificationException catch (e) {
      _error = e.message;
      codeController.clear();
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }
}
