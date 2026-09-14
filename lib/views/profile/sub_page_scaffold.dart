import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------
// Shared page shell for the simple Profile sub-pages
// ---------------------------------------------------------------------
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
  // Spacer() + Flexible(value) used to split the leftover space 50/50 (both
  // default to flex:1), so the value text only filled part of its own
  // loosely-fit box and the chevron — placed right after it in the Row —
  // ended up wherever that text happened to end, not at a fixed right edge.
  // That's why the chevrons drifted left/right with the value's length.
  // Expanded on the label instead soaks up all the leftover space, so
  // value+gap+chevron are always packed as one tight group flush against
  // the row's true right edge, regardless of how long the value text is.
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
