import 'package:flutter/material.dart';

import 'theme.dart';

// ---------------------------------------------------------------------
// Group Info
// ---------------------------------------------------------------------
class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const memberCount = 7;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                AppImage('assets/images/adventure_bg.jpg', height: 190, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ],
            ),
            // The info card overlaps the bottom of the header photo — a
            // negative top margin pulls it up over the image (this reflows
            // the siblings below it too, unlike Transform, so nothing else
            // needs adjusting to close the gap it leaves).
            Container(
              margin: const EdgeInsets.only(top: -22, left: 16, right: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Japan Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  const Text('12 - 19 June 2026', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  const Text('$memberCount members', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...List.generate(memberCount - 1, (i) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CircleAvatar(radius: 18, backgroundColor: Colors.primaries[i % Colors.primaries.length]),
                            )),
                        GestureDetector(
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite link copied — share it with your friends')),
                          ),
                          child: const CircleAvatar(radius: 18, backgroundColor: AppColors.chipGrey, child: Icon(Icons.add, color: AppColors.navy)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  const Text(
                    "This is our Japan adventure\nLet's make amazing memories together!",
                    style: TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _menuGroup([
                    _MenuEntry(Icons.warning_amber_outlined, 'Emergency',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Emergency contacts and hotlines for this trip')))),
                    _MenuEntry(Icons.volunteer_activism_outlined, 'Saved List',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Showing places this group has saved')))),
                    _MenuEntry(Icons.location_on_outlined, 'Member Location',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Member Location needs Real-Time Location turned on in Group Setting')))),
                  ]),
                  const SizedBox(height: 14),
                  _menuGroup([
                    _MenuEntry(Icons.settings_outlined, 'Group Setting',
                        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupSettingPage()))),
                    _MenuEntry(Icons.ios_share_outlined, 'Export Itinerary',
                        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportItineraryPage()))),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuGroup(List<_MenuEntry> entries) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: entries.map((e) {
          final isLast = e == entries.last;
          return InkWell(
            onTap: e.onTap,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(e.icon, color: AppColors.navy, size: 20),
                      const SizedBox(width: 14),
                      Expanded(child: Text(e.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy))),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MenuEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _MenuEntry(this.icon, this.label, this.onTap);
}

// ---------------------------------------------------------------------
// Export Itinerary
// ---------------------------------------------------------------------
class ExportItineraryPage extends StatefulWidget {
  const ExportItineraryPage({super.key});

  @override
  State<ExportItineraryPage> createState() => _ExportItineraryPageState();
}

class _ExportItineraryPageState extends State<ExportItineraryPage> {
  String _format = 'PDF';

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Itinerary exported as $_format')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Export Itinerary', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Export format', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _formatChip('PDF', Icons.picture_as_pdf_outlined),
                    const SizedBox(width: 10),
                    _formatChip('Image', Icons.image_outlined),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.textGrey),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The full day-by-day plan, flights, hotels and expenses for this group will be included.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _export,
                child: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label, IconData icon) {
    final selected = _format == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.chipGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.textGrey),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Group Setting
// ---------------------------------------------------------------------
class GroupSettingPage extends StatefulWidget {
  const GroupSettingPage({super.key});

  @override
  State<GroupSettingPage> createState() => _GroupSettingPageState();
}

class _GroupSettingPageState extends State<GroupSettingPage> {
  bool _muteChat = true;
  bool _pinChat = true;
  bool _realTimeLocation = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Group Setting', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _navRow('Group Name', 'Japan Trips'),
          _photoRow(),
          _navRow('Group About', "This is our Japan adventure\nLet's make amazing memories together!"),
          _navRow('Notification', 'All Message'),
          _switchRow('Mute Chat', _muteChat, (v) => setState(() => _muteChat = v)),
          _switchRow('Pin Chat', _pinChat, (v) => setState(() => _pinChat = v)),
          _switchRow('Real-Time Location', _realTimeLocation, (v) => setState(() => _realTimeLocation = v)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _confirmLeaveGroup(context),
              child: const Text('Leave Group', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Group', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure you want to leave this group? You'll lose access to its plan, chat and expenses.",
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have left the group')),
              );
            },
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _navRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
          const Spacer(),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _photoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          const Text('Group Photo', style: TextStyle(fontSize: 13.5, color: Colors.black)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AppImage('assets/images/adventure_bg.jpg', width: 36, height: 36, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
