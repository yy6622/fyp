import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../services/verification_service.dart';
import '../../theme.dart';
import '../onboarding/onboarding_wizard_page.dart';
import '../shared/bottom_nav.dart';
import 'login_page.dart';

/// After a successful sign-in (password or Google), decides where the
/// traveller goes: the email-code page (unverified email, or a device that is
/// not trusted yet) or straight into the app (FR04).
Future<void> openAppAfterSignIn(BuildContext context, {bool newUser = false}) async {
  final step = await VerificationService.instance.nextStep();
  if (!context.mounted) return;
  if (step == SignInStep.suspended) {
    // FR96: a suspended account is signed out straight away.
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    messenger.showSnackBar(const SnackBar(content: Text(suspendedMessage)));
    return;
  }
  Widget home() => newUser ? const OnboardingWizardPage() : const MainPage();
  final Widget target = switch (step) {
    SignInStep.open || SignInStep.suspended => home(),
    SignInStep.verifyEmail => VerificationCodePage(purpose: CodePurpose.signup, next: home),
    SignInStep.verifyDevice => VerificationCodePage(purpose: CodePurpose.login, next: home),
  };
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => target), (route) => false);
}

/// Asks for a fresh email code before a sensitive action (payment, password,
/// email or account deletion). Returns true only when the code was right.
Future<bool> confirmWithEmailCode(BuildContext context, CodePurpose purpose) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => VerificationCodePage(purpose: purpose)),
  );
  return ok == true;
}

class VerificationCodePage extends StatefulWidget {
  final CodePurpose purpose;

  /// Where to go after a correct sign-up / sign-in code. Null for step-up
  /// purposes, which pop back with `true`.
  final Widget Function()? next;

  const VerificationCodePage({super.key, required this.purpose, this.next});

  @override
  State<VerificationCodePage> createState() => _VerificationCodePageState();
}

class _VerificationCodePageState extends State<VerificationCodePage> {
  late final VerificationCodeController controller = VerificationCodeController(widget.purpose);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial: true));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send({bool initial = false}) async {
    final error = await controller.send();
    if (!mounted || initial || error != null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A new code was sent to ${controller.email}')));
  }

  Future<void> _verify() async {
    final ok = await controller.verify();
    if (!ok || !mounted) return;
    final next = widget.next;
    if (next != null) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => next()), (route) => false);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _close() async {
    if (widget.purpose.isStepUp) {
      Navigator.of(context).pop(false);
      return;
    }
    // Sign-up and sign-in cannot be skipped: leaving signs the traveller out.
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: Icon(widget.purpose.isStepUp ? Icons.arrow_back : Icons.close, color: Colors.black),
                    onPressed: _close,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    widget.purpose.title,
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a 6-digit code to ${controller.email} ${widget.purpose.reason}. '
                    'It expires in 10 minutes.',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                  ),
                  if (widget.purpose == CodePurpose.login) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'After this, this phone is trusted for 30 days.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
                      child: const Icon(Icons.mark_email_unread_outlined, size: 40, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('verification_code_field'),
                    controller: controller.codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
                    onChanged: (v) {
                      if (v.length == 6 && !controller.checking) _verify();
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), letterSpacing: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 8),
                    Text(controller.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: controller.checking ? null : _verify,
                      child: controller.checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: controller.sending || controller.resendIn > 0 ? null : () => _send(),
                      child: Text(
                        controller.sending
                            ? 'Sending…'
                            : controller.resendIn > 0
                                ? 'Resend code in ${controller.resendIn} s'
                                : 'Resend code',
                        style: TextStyle(
                          fontSize: 16,
                          color: controller.resendIn > 0 ? const Color(0xFFBDBDBD) : const Color(0xFF939292),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
