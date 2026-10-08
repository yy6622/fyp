import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around [FirebaseAuth] — the one place that talks to Firebase
/// Authentication directly, so every screen gets the same error handling.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// True the first time this Firebase account has ever signed in (no
  /// sign-in before this one) — Google/Facebook sign-in skips the normal
  /// Sign Up form, so this is how the caller tells "brand new account,
  /// go through onboarding" apart from "welcome back, go straight in".
  bool isNewUser(UserCredential cred) => cred.additionalUserInfo?.isNewUser ?? false;

  Future<User> signUp({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  /// Re-fetches the current user's record from Firebase, so a verification
  /// link clicked in another tab/app is picked up. Returns the fresh
  /// emailVerified flag.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {
      // Reload can fail if e.g. offline — fall through with whatever we had.
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Opens Google's account picker and signs in to Firebase with whatever
  /// account is chosen, creating the Firebase account automatically the
  /// first time. Returns null if the person closed the picker without
  /// choosing an account — that's a cancel, not an error, so nothing is
  /// shown for it.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      // GoogleSignIn itself throws plain PlatformExceptions (wrong SHA-1
      // fingerprint registered in Firebase, Play Services missing on the
      // device/emulator, no internet, ...), not FirebaseAuthException —
      // there's nothing a person can act on in that raw error, so it's
      // collapsed to one message same as the other providers below.
      throw AuthFailure('Google sign-in failed. Please try again.');
    }
  }

  /// Same shape as [signInWithGoogle], for Facebook Login.
  Future<UserCredential?> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(permissions: const ['email', 'public_profile']);
      if (result.status == LoginStatus.cancelled) return null;
      final token = result.accessToken;
      if (result.status != LoginStatus.success || token == null) {
        throw AuthFailure(result.message ?? 'Facebook sign-in failed. Please try again.');
      }
      final credential = FacebookAuthProvider.credential(token.tokenString);
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw AuthFailure('Facebook sign-in failed. Please try again.');
    }
  }

  /// Signs out of Firebase and of whichever social provider session might
  /// still be active — best-effort: an email/password user has no Google/
  /// Facebook session to end, and those calls would just no-op/throw
  /// harmlessly, which must never block the actual Firebase sign-out.
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'That password is too weak.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists for this email, signed up a different way (e.g. email/password or another provider). Log in with that method instead.';
      default:
        return e.message ?? 'Something went wrong (${e.code}).';
    }
  }
}

/// A user-facing auth error message, already safe to show in a SnackBar.
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}
