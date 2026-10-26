import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  /// sign-in before this one) — Google sign-in skips the normal
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
      debugPrint('[Google Sign-In] FirebaseAuthException: ${e.code} — ${e.message}');
      throw AuthFailure(_message(e));
    } catch (e, st) {
      // GoogleSignIn itself throws plain PlatformExceptions (wrong SHA-1
      // fingerprint registered in Firebase, Play Services missing on the
      // device/emulator, no internet, ...), not FirebaseAuthException —
      // there's nothing a person can act on in that raw error, so it's
      // collapsed to one message same as the other providers below.
      // TEMP DIAGNOSTIC: print the real underlying error/stack to the
      // debug console so it can actually be diagnosed instead of always
      // showing the same generic message — remove once Google Sign-In is
      // confirmed working end-to-end.
      debugPrint('[Google Sign-In] raw error: $e');
      debugPrint('[Google Sign-In] stack: $st');
      throw AuthFailure('Google sign-in failed. Please try again.');
    }
  }

  /// Signs out of Firebase and of the Google session, if any — best-effort:
  /// an email/password user has no Google session to end, and this call
  /// would just no-op/throw harmlessly, which must never block the actual
  /// Firebase sign-out.
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

  // ---------------------------------------------------------------------
  // Password/Email change + account deletion — Firebase requires a
  // RECENT sign-in for all three (reauthenticateWithCredential), which is
  // why every one of these takes the person's current password first,
  // same as changing a password on almost any other app. Account Setting
  // previously showed "Password"/"Email" rows styled exactly like the
  // real editable rows below them (chevron, tappable-looking) with no
  // onTap at all, and "Delete Account" asked for confirmation then threw
  // the answer away — none of the three ever called anything here.
  // ---------------------------------------------------------------------

  /// Re-proves the signed-in person is who they say with their current
  /// password — required by Firebase immediately before [changePassword],
  /// [changeEmail] or [deleteAccount]. Throws [AuthFailure] on a wrong
  /// password or any other auth error.
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

  /// Sends a verification link to [newEmail] rather than swapping it
  /// immediately (`updateEmail` is deprecated/blocked on current Firebase
  /// projects) — the email on the account only actually changes once the
  /// person clicks that link, same as how `sendEmailVerification` works
  /// elsewhere in this file.
  Future<void> changeEmail({required String currentPassword, required String newEmail}) async {
    await _reauthenticate(currentPassword);
    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  /// Deletes the Firebase Auth account itself. Does NOT cascade-delete
  /// this person's trips, group memberships, posts or other Firestore
  /// data — that would mean reassigning or deleting other people's
  /// shared data (a trip they co-own with friends, posts others have
  /// liked/reviewed) well beyond "delete my own account", so it's left
  /// for a future pass rather than guessed at here. The caller deletes
  /// the person's own `users/{uid}` profile doc separately (see
  /// AccountSettingPage._deleteAccount) since that one is unambiguously
  /// theirs alone.
  Future<void> deleteAccount(String currentPassword) async {
    await _reauthenticate(currentPassword);
    try {
      await _auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
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
