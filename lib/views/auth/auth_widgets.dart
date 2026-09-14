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

Widget socialLoginRow(String label) {
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
          socialIconButton('assets/images/google_icon.png'),
          const SizedBox(width: 16),
          socialIconButton('assets/images/facebook_icon.png'),
        ],
      ),
    ],
  );
}

Widget socialIconButton(String asset) {
  return Container(
    width: 50,
    height: 50,
    decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle),
    padding: const EdgeInsets.all(9),
    child: AppImage(asset, fit: BoxFit.contain),
  );
}
