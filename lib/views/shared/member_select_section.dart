import 'package:flutter/material.dart';

import '../../theme.dart';

class MemberSelectSection extends StatelessWidget {
  final Map<String, String> memberNames;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const MemberSelectSection({
    super.key,
    required this.memberNames,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final members = memberNames.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who Is This For?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const Text('Everyone on this trip can see who a booking applies to.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members.map((e) {
            final uid = e.key;
            final name = e.value;
            final checked = selected.contains(uid);
            return GestureDetector(
              onTap: () {
                final next = {...selected};
                if (checked) {
                  if (next.length > 1) next.remove(uid);
                } else {
                  next.add(uid);
                }
                onChanged(next);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: checked ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: checked ? AppColors.primary : const Color(0xFFECECEC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(checked ? Icons.check_circle : Icons.circle_outlined, size: 16, color: checked ? AppColors.primary : AppColors.textGrey),
                    const SizedBox(width: 6),
                    Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: checked ? AppColors.primary : Colors.black)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

String forMembersLabel(List<String> forMemberUids, Map<String, String> memberNames) {
  if (forMemberUids.isEmpty || forMemberUids.length >= memberNames.length) return '';
  final names = forMemberUids.map((uid) => memberNames[uid]).whereType<String>().where((n) => n.isNotEmpty).toList();
  if (names.isEmpty) return '';
  return 'For: ${names.join(', ')}';
}
