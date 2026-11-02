import 'package:flutter/material.dart';

import '../../theme.dart';

class SubPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  const SubPageScaffold({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: body,
    );
  }
}

Widget profileNavRow(String label, String value, {VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black))),
          Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
        ],
      ),
    ),
  );
}
