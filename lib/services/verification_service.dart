import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/user_repository.dart';
import 'auth_service.dart';

/// Why a 6-digit email code is being asked for (FR04).
enum CodePurpose {
  signup('signup', 'Verify Your Email', 'to verify your email address'),
  login('login', 'New Device Sign-in', 'because this is a new device'),
  payment('payment', 'Confirm Payment', 'to confirm this payment'),
  changePassword('change_password', 'Confirm Password Change', 'to change your password'),
  changeEmail('change_email', 'Confirm Email Change', 'to change your email address'),
  deleteAccount('delete_account', 'Confirm Account Deletion', 'to delete your account');

  final String wire;
  final String title;
  final String reason;
  const CodePurpose(this.wire, this.title, this.reason);

  /// Step-up purposes confirm one action and then return to the previous screen.
  bool get isStepUp => this != CodePurpose.signup && this != CodePurpose.login;
}

/// What has to happen after a traveller signs in before the app opens.
enum SignInStep { suspended, verifyEmail, verifyDevice, open }

class VerificationException implements Exception {
  final String message;
  const VerificationException(this.message);
  @override
  String toString() => message;
}

/// Email-code verification (FR04): sign-up, new-device sign-in, and step-up
/// confirmation before payments and account changes. Codes are created and
/// checked by the sendVerificationCode / verifyCode Cloud Functions.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  static const _deviceIdKey = 'voya_device_id';
  String? _deviceId;

  /// A random id for this installation, kept on the phone. A device is
  /// "trusted" when users/{uid}/trusted_devices/{deviceId} has not expired.
  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.length < 8) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      final rnd = Random.secure();
      id = List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return _deviceId = id;
  }

  String get deviceName {
    try {
      if (Platform.isAndroid) return 'Android phone';
      if (Platform.isIOS) return 'iPhone';
    } catch (_) {}
    return 'Phone';
  }

  Future<bool> isDeviceTrusted(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trusted_devices')
          .doc(await deviceId())
          .get();
      final until = doc.data()?['trustedUntil'];
      return until is num && until > DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  /// Decides what a signed-in traveller must do before the app opens.
  Future<SignInStep> nextStep() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return SignInStep.verifyEmail;
    try {
      await user.reload();
    } catch (_) {}
    final fresh = AuthService.instance.currentUser ?? user;
    if (await UserRepository.instance.isSuspended(fresh.uid)) return SignInStep.suspended;
    if (!fresh.emailVerified) return SignInStep.verifyEmail;
    if (!await isDeviceTrusted(fresh.uid)) return SignInStep.verifyDevice;
    return SignInStep.open;
  }

  Future<void> sendCode(CodePurpose purpose) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('sendVerificationCode').call({'purpose': purpose.wire});
    } on FirebaseFunctionsException catch (e) {
      throw VerificationException(e.message ?? 'Could not send the code (${e.code}).');
    } catch (_) {
      throw const VerificationException('Could not send the code. Check your connection and try again.');
    }
  }

  Future<void> verifyCode(CodePurpose purpose, String code) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('verifyCode').call({
        'purpose': purpose.wire,
        'code': code.trim(),
        'deviceId': await deviceId(),
        'deviceName': deviceName,
      });
    } on FirebaseFunctionsException catch (e) {
      throw VerificationException(e.message ?? 'That code did not work (${e.code}).');
    } catch (_) {
      throw const VerificationException('Could not check the code. Check your connection and try again.');
    }
    if (purpose == CodePurpose.signup) {
      try {
        await AuthService.instance.currentUser?.reload();
      } catch (_) {}
    }
  }

  /// Removes every trusted device, so the next sign-in anywhere needs a code.
  Future<int> forgetTrustedDevices(String uid) async {
    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('trusted_devices');
    final snap = await col.get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
    return snap.docs.length;
  }
}
