import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

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

  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

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
      debugPrint('[Google Sign-In] FirebaseAuthException: ${e.code} — ${e.message}');
      throw AuthFailure(_message(e));
    } catch (e, st) {
      debugPrint('[Google Sign-In] raw error: $e');
      debugPrint('[Google Sign-In] stack: $st');
      throw AuthFailure('Google sign-in failed. Please try again.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
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


  Future<void> _reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw AuthFailure('You need to be signed in to do this.');
    }
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: currentPassword));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.code == 'invalid-credential' || e.code == 'wrong-password'
          ? 'That password is incorrect.'
          : _message(e));
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _reauthenticate(currentPassword);
    try {
      await _auth.currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> changeEmail({required String currentPassword, required String newEmail}) async {
    await _reauthenticate(currentPassword);
    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> deleteAccount(String currentPassword) async {
    await _reauthenticate(currentPassword);
    try {
      await _auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }
}

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}
