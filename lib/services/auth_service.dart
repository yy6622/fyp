import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around [FirebaseAuth] — the one place that talks to Firebase
/// Authentication directly, so every screen gets the same error handling.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

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

  Future<void> signOut() => _auth.signOut();

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
