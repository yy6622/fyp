// Account Management Module - TC01, TC02, TC03, TC05, TC40, TC41, TC49, TC50, TC61, TC71.
// Calls the same controllers/repositories the Login, Sign Up, Forgot Password,
// Friends and Profile screens use, against the Firebase emulators.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/controllers/auth_controller.dart';
import 'package:voya/repositories/friends_repository.dart';
import 'package:voya/repositories/user_repository.dart';
import 'package:voya/services/auth_service.dart';
import 'package:voya/services/verification_service.dart';

import 'helpers/test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestUser friendA, friendB;

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
  });

  testWidgets('TC01 Register with valid details creates the account and profile', (tester) async {
    final c = SignupController();
    final email = 'tc01.$runId@voya.test';
    c.usernameController.text = 'Test User';
    c.emailController.text = email;
    c.passwordController.text = testPassword;
    c.confirmController.text = testPassword;

    final error = await c.signUp();

    expect(error, isNull);
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    expect(user!.email, email);
    final profile = await UserRepository.instance.fetchProfile(user.uid);
    expect(profile?.name, 'Test User');
    expect(profile?.email, email);
    expect(await VerificationService.instance.nextStep(), SignInStep.verifyEmail,
        reason: 'the new account must enter the 6-digit email code before using the app');
    c.dispose();
  });

  testWidgets('TC02 Register with invalid email is refused', (tester) async {
    await FirebaseAuth.instance.signOut();
    final c = SignupController();
    c.usernameController.text = 'Test User';
    c.emailController.text = 'abc@';
    c.passwordController.text = testPassword;
    c.confirmController.text = testPassword;

    final error = await c.signUp();

    expect(error, 'That email address looks invalid.');
    expect(FirebaseAuth.instance.currentUser, isNull);
    c.dispose();
  });

  testWidgets('TC03 Login with wrong password is refused', (tester) async {
    final user = await createTraveller('Tc03 User');
    await FirebaseAuth.instance.signOut();
    final c = LoginController();
    c.emailController.text = user.email;
    c.passwordController.text = 'Wrong@999';

    final error = await c.login();

    expect(error, 'Incorrect email or password.');
    expect(FirebaseAuth.instance.currentUser, isNull);

    c.passwordController.text = testPassword;
    expect(await c.login(), isNull, reason: 'the right password still works');
    expect(FirebaseAuth.instance.currentUser?.uid, user.uid);
    c.dispose();
  });

  testWidgets('TC05 Two-step verification: email code at sign-up, then only on new devices', (tester) async {
    // FR04. Codes themselves are created and checked by the sendVerificationCode /
    // verifyCode Cloud Functions (tests/functions, TC05). Here the app's gate and
    // the Firestore rules that protect it are checked against the emulators.
    final user = await createTraveller('Tc05 User');
    final verification = VerificationService.instance;
    final deviceId = await verification.deviceId();
    final devicePath = 'users/${user.uid}/trusted_devices/$deviceId';

    expect(await verification.nextStep(), SignInStep.verifyEmail, reason: 'unverified email -> sign-up code');

    await markEmailVerified(user.uid);
    expect(await verification.nextStep(), SignInStep.verifyDevice, reason: 'new device -> sign-in code');

    await expectDenied(
      () => FirebaseFirestore.instance.doc(devicePath).set({'trustedUntil': 9999999999999}),
      reason: 'the app cannot mark its own device as trusted',
    );
    await expectDenied(() => FirebaseFirestore.instance.doc('verification_codes/${user.uid}_login').get(),
        reason: 'stored codes are server-only');
    await expectDenied(() => FirebaseFirestore.instance.doc('step_up/${user.uid}').set({'payment': 9999999999999}),
        reason: 'the app cannot fake a payment confirmation');

    // What verifyCode writes after a correct code: trusted for 30 days.
    final now = DateTime.now().millisecondsSinceEpoch;
    await seedDoc(devicePath, {'name': 'Android phone', 'trustedAt': now, 'trustedUntil': now + 30 * 24 * 3600 * 1000});
    expect(await verification.nextStep(), SignInStep.open, reason: 'trusted device -> password only');

    await seedDoc(devicePath, {'name': 'Android phone', 'trustedAt': now, 'trustedUntil': now - 1000});
    expect(await verification.nextStep(), SignInStep.verifyDevice, reason: 'after 30 days a code is needed again');

    await seedDoc(devicePath, {'name': 'Android phone', 'trustedAt': now, 'trustedUntil': now + 1000000});
    expect(await verification.forgetTrustedDevices(user.uid), 1);
    expect(await verification.nextStep(), SignInStep.verifyDevice, reason: 'Sign Out of Trusted Devices works');
  });

  testWidgets('TC49 Forgot password sends a reset email', (tester) async {
    final user = await createTraveller('Tc49 User');
    await FirebaseAuth.instance.signOut();
    final c = ForgotPasswordController();
    c.emailController.text = user.email;

    expect(await c.sendResetLink(), isNull);

    final mails = await authEmulatorEmails();
    expect(mails.any((m) => m['email'] == user.email && m['requestType'] == 'PASSWORD_RESET'), isTrue);
    c.emailController.text = '';
    expect(await c.sendResetLink(), 'Enter your registered email address.');
    c.dispose();
  });

  testWidgets('TC50 Log out ends the session', (tester) async {
    final user = await createTraveller('Tc50 User');
    expect(FirebaseAuth.instance.currentUser?.uid, user.uid);

    await AuthService.instance.signOut();

    expect(FirebaseAuth.instance.currentUser, isNull);
    await expectDenied(
      () => FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      reason: 'protected data needs a signed-in user',
    );
  });

  testWidgets('TC40 Send and accept a friend request', (tester) async {
    final b = await createTraveller('Bella');
    final a = await createTraveller('Ali');

    final outcome = await FriendsRepository.instance.sendFriendRequest(myUid: a.uid, myName: a.name, query: b.email);
    expect(outcome.status, FriendRequestStatus.sent);

    await signInAs(b);
    final incoming = await FriendsRepository.instance.watchIncomingRequests(b.uid).first;
    expect(incoming.map((r) => r.fromUid), contains(a.uid));
    await FriendsRepository.instance
        .respondToFriendRequest(uid: b.uid, fromUid: a.uid, fromName: a.name, myName: b.name, accept: true);

    final bFriends = await FriendsRepository.instance.watchFriends(b.uid).first;
    expect(bFriends.map((f) => f.uid), contains(a.uid));
    await signInAs(a);
    final aFriends = await FriendsRepository.instance.watchFriends(a.uid).first;
    expect(aFriends.map((f) => f.uid), contains(b.uid));

    friendA = a;
    friendB = b;
  });

  testWidgets('TC71 Remove a friend (FR07)', (tester) async {
    await signInAs(friendA);
    await FriendsRepository.instance.removeFriend(uid: friendA.uid, friendUid: friendB.uid);
    expect((await FriendsRepository.instance.watchFriends(friendA.uid).first).map((f) => f.uid),
        isNot(contains(friendB.uid)));
    await signInAs(friendB);
    expect((await FriendsRepository.instance.watchFriends(friendB.uid).first).map((f) => f.uid),
        isNot(contains(friendA.uid)));
  });

  testWidgets('TC41 Block a user', (tester) async {
    final b = await createTraveller('Blocked Bob');
    final a = await createTraveller('Blocker Amy');

    await FriendsRepository.instance.setBlocked(uid: a.uid, friendUid: b.uid, friendName: b.name, blocked: true);
    expect((await FriendsRepository.instance.watchBlockedIds(a.uid).first), contains(b.uid));

    await FriendsRepository.instance.setBlocked(uid: a.uid, friendUid: b.uid, friendName: b.name, blocked: false);
    expect((await FriendsRepository.instance.watchBlockedIds(a.uid).first), isNot(contains(b.uid)));
  });

  testWidgets('TC61 A suspended traveller cannot log in', (tester) async {
    // FR96. The admin console marks the account suspended (users/{uid}.status);
    // the app checks it right after the password is accepted.
    final user = await createTraveller('Tc61 User');
    await seedDoc('users/${user.uid}', {
      'name': user.name,
      'email': user.email,
      'status': 'suspended',
    });
    await FirebaseAuth.instance.signOut();
    final c = LoginController();
    c.emailController.text = user.email;
    c.passwordController.text = testPassword;

    final error = await c.login();

    expect(error, suspendedMessage, reason: 'a suspended account should see an error');
    expect(FirebaseAuth.instance.currentUser, isNull);
    c.dispose();
  });
}
