import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------
// Shared bits: text field + social login row
// ---------------------------------------------------------------------
class AuthTextField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final Widget? suffixIcon;
  final TextEditingController? controller;

  const AuthTextField({
    super.key,
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

// [onGoogle]/[onFacebook] were previously unset — the two circles below
// were plain decoration with no onTap at all. [googleBusy]/[facebookBusy]
// show a small spinner in place of the icon (and disable both buttons)
// while that provider's sign-in is in flight, the same shape the rest of
// this app's buttons use for a loading state.
Widget socialLoginRow(
  String label, {
  required VoidCallback onGoogle,
  required VoidCallback onFacebook,
  bool googleBusy = false,
  bool facebookBusy = false,
}) {
  final busy = googleBusy || facebookBusy;
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
          socialIconButton('assets/images/google_icon.png', onTap: onGoogle, busy: googleBusy, disabled: busy && !googleBusy),
          const SizedBox(width: 16),
          socialIconButton('assets/images/facebook_icon.png', onTap: onFacebook, busy: facebookBusy, disabled: busy && !facebookBusy),
        ],
      ),
    ],
  );
}

Widget socialIconButton(String asset, {required VoidCallback onTap, bool busy = false, bool disabled = false}) {
  return GestureDetector(
    onTap: (busy || disabled) ? null : onTap,
    child: Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle),
        padding: const EdgeInsets.all(9),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(5),
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
              )
            : AppImage(asset, fit: BoxFit.contain),
      ),
    ),
  );
}
