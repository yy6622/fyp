import 'package:flutter/material.dart';

import '../../theme.dart';

Future<void> showPersonInfoSheet(
  BuildContext context, {
  required String name,
  required String roleLabel,
  String email = '',
  String phone = '',
  String idNumber = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.person_outline, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Not available' : name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 2),
                      Text(roleLabel, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFECECEC)),
            const SizedBox(height: 14),
            if (email.isNotEmpty) _infoRow(Icons.email_outlined, 'Email', email),
            if (phone.isNotEmpty) _infoRow(Icons.call_outlined, 'Phone', phone),
            if (idNumber.isNotEmpty) _infoRow(Icons.badge_outlined, 'Passport / ID Number', idNumber),
            if (email.isEmpty && phone.isEmpty && idNumber.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('No further details on file for this person.', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
            ],
          ),
        ),
      ],
    ),
  );
}
