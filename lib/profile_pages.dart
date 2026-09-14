import 'package:flutter/material.dart';

import 'detail_pages.dart';
import 'insurance.dart';
import 'theme.dart';

// ---------------------------------------------------------------------
// Shared page shell
// ---------------------------------------------------------------------
class _SubPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  const _SubPageScaffold({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: body,
    );
  }
}

Widget _navRow(String label, String value, {VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black)),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// Account Setting
// ---------------------------------------------------------------------
class AccountSettingPage extends StatelessWidget {
  const AccountSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Account Setting',
      body: ListView(
        children: [
          _navRow('Username', 'Alice Tan'),
          InkWell(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
              child: Row(
                children: [
                  const Text('Avatar', style: TextStyle(fontSize: 14, color: Colors.black)),
                  const Spacer(),
                  const CircleAvatar(radius: 18, backgroundColor: Color(0xFFD9D9D9)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
                ],
              ),
            ),
          ),
          _navRow('Password', '••••••••'),
          _navRow('Email', 'alicetan123@gmail.com'),
          _navRow('Phone Number', '+60 12-345 6789'),
          _navRow('Language', 'English'),
          _navRow('Country / Region', 'Malaysia'),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete Account', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                    content: const Text(
                      'This permanently deletes your account and all your trips. This cannot be undone. Are you sure?',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Travel Preferences
// ---------------------------------------------------------------------
class TravelPreferencesPage extends StatelessWidget {
  const TravelPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Travel Preferences',
      body: ListView(
        children: [
          _navRow('Travel Style', 'Adventure'),
          _navRow('Budget', 'RM 2,000 - RM 5,000'),
          _navRow('Accommodation', 'Hotel'),
          _navRow('Food Preference', 'No restrictions'),
          _navRow('Interests', 'Culture, Food, Nature'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Chat Setting
// ---------------------------------------------------------------------
class ChatSettingPage extends StatefulWidget {
  const ChatSettingPage({super.key});

  @override
  State<ChatSettingPage> createState() => _ChatSettingPageState();
}

class _ChatSettingPageState extends State<ChatSettingPage> {
  bool _saveMedia = true;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Chat Setting',
      body: ListView(
        children: [
          _navRow('Auto Download Media', 'Wifi Only'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Save Media to Gallery', style: TextStyle(fontSize: 14, color: Colors.black)),
                Switch(value: _saveMedia, activeColor: AppColors.primary, onChanged: (v) => setState(() => _saveMedia = v)),
              ],
            ),
          ),
          _navRow('Blocked Users', '2', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersPage()))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Blocked Users
// ---------------------------------------------------------------------
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final List<String> _blocked = ['Loh Li Mei', 'Chew Wen Mei'];

  void _unblock(String name) {
    setState(() => _blocked.remove(name));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name has been unblocked')));
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Blocked Users',
      body: _blocked.isEmpty
          ? const Center(child: Text('No blocked users', style: TextStyle(color: AppColors.textGrey)))
          : ListView.separated(
              itemCount: _blocked.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE4E4E4)),
              itemBuilder: (context, i) {
                final name = _blocked[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 20, backgroundColor: Color(0xFFD9D9D9)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black))),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _unblock(name),
                        child: const Text('Unblock', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------
// Friends — a plain friends list with block/unblock, not a chat list.
// ---------------------------------------------------------------------
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final List<String> _friends = ['Yeoh Li Mei', 'Tan Ah Bu', 'Lew Xiao Fen', 'Loh Jun Jie'];
  final Set<String> _blocked = {};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleBlock(String name) {
    setState(() {
      if (_blocked.contains(name)) {
        _blocked.remove(name);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name has been unblocked')));
      } else {
        _blocked.add(name);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name has been blocked')));
      }
    });
  }

  void _openAddFriend() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Friend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Username or email',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.chipGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final value = ctrl.text.trim();
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value.isEmpty ? 'Enter a username or email first' : 'Friend request sent to $value'),
                    ),
                  );
                },
                child: const Text('Send Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty ? _friends : _friends.where((f) => f.toLowerCase().contains(query)).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Friends', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search friends',
                  hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  prefixIcon: Icon(Icons.search, color: AppColors.textGrey, size: 20),
                ),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No friends found', style: TextStyle(color: AppColors.textGrey)))
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE4E4E4)),
                    itemBuilder: (context, i) {
                      final name = visible[i];
                      final blocked = _blocked.contains(name);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            const CircleAvatar(radius: 20, backgroundColor: Color(0xFFD9D9D9)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                            GestureDetector(
                              onTap: () => _toggleBlock(name),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: blocked ? Colors.redAccent : const Color(0xFFD9D9D9)),
                                ),
                                child: Icon(
                                  Icons.block,
                                  size: 16,
                                  color: blocked ? Colors.redAccent : AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _openAddFriend,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// History (Flight / Hotel / Insurance tabs)
// ---------------------------------------------------------------------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

enum _HistoryTab { flight, hotel, insurance }

class _HistoryPageState extends State<HistoryPage> {
  _HistoryTab _tab = _HistoryTab.flight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('History', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline, color: AppColors.navy),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new booking updates')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: _tabButton('Flight', _HistoryTab.flight)),
              Expanded(child: _tabButton('Hotel', _HistoryTab.hotel)),
              Expanded(child: _tabButton('Insurance', _HistoryTab.insurance)),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFECECEC)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('March', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                Row(
                  children: const [
                    Text('Filter', style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                    SizedBox(width: 4),
                    Icon(Icons.filter_list, size: 16, color: AppColors.navy),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: 4,
              itemBuilder: (context, i) => _historyRow(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _HistoryTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
      ),
    );
  }

  Widget _historyRow(BuildContext context) {
    final icon = switch (_tab) {
      _HistoryTab.flight => Icons.flight_takeoff,
      _HistoryTab.hotel => Icons.hotel_outlined,
      _HistoryTab.insurance => Icons.shield_outlined,
    };
    final title = switch (_tab) {
      _HistoryTab.flight => 'KL → KUI',
      _HistoryTab.hotel => 'L Hotel, Shinjoku',
      _HistoryTab.insurance => 'Standard Travel Cover',
    };
    final subtitle = switch (_tab) {
      _HistoryTab.flight => '12 June 2026 13:30',
      _HistoryTab.hotel => '12 - 15 June 2026',
      _HistoryTab.insurance => 'Policy #INS-20260612',
    };
    final trailing = switch (_tab) {
      _HistoryTab.flight => 'One Way',
      _HistoryTab.hotel => 'RM 960 total',
      _HistoryTab.insurance => 'RM 45',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openHistoryDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFE4372A), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
            Text(trailing, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  // Tapping a past booking used to do nothing at all — this is what was
  // meant by "flight and hotel detail page at history need to be link".
  void _openHistoryDetail(BuildContext context) {
    switch (_tab) {
      case _HistoryTab.flight:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetailPageFlight()));
        break;
      case _HistoryTab.hotel:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetailPageHotel()));
        break;
      case _HistoryTab.insurance:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => InsurancePlanDetailPage(plan: insurancePlans.first)),
        );
        break;
    }
  }
}

// ---------------------------------------------------------------------
// Report New Attraction
// ---------------------------------------------------------------------
class ReportAttractionPage extends StatefulWidget {
  const ReportAttractionPage({super.key});

  @override
  State<ReportAttractionPage> createState() => _ReportAttractionPageState();
}

class _ReportAttractionPageState extends State<ReportAttractionPage> {
  bool _mediaAdded = false;
  final _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a location first')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks! Your new spot has been reported for review.')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Report New Attraction',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Upload Media', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _mediaAdded = !_mediaAdded),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFECECEC)),
                      borderRadius: BorderRadius.circular(10),
                      color: _mediaAdded ? AppColors.chipGrey : Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: _mediaAdded
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Photo added — tap to remove', style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                            ],
                          )
                        : const Icon(Icons.file_upload_outlined, color: AppColors.textGrey),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search location',
                    hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                    suffixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
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
                onPressed: _submit,
                child: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Privacy and Security
// ---------------------------------------------------------------------
class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _profileVisible = true;
  bool _shareLocation = true;
  bool _twoFactor = false;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Privacy and Security',
      body: ListView(
        children: [
          _switchTile('Public Profile', 'Let other travellers find and follow you', _profileVisible,
              (v) => setState(() => _profileVisible = v)),
          _switchTile('Share Location with Group', 'Group members can see your live location during a trip', _shareLocation,
              (v) => setState(() => _shareLocation = v)),
          _switchTile('Two-Factor Authentication', 'Add an extra layer of security when logging in', _twoFactor,
              (v) => setState(() => _twoFactor = v)),
          _navRow('Change Password', ''),
          _navRow('Download My Data', ''),
        ],
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Help and Support
// ---------------------------------------------------------------------
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const _faqs = [
    ('How do I create a group trip?', 'Go to the Plan tab and tap the + button to start a new trip and invite friends.'),
    ('How do I cancel a booking?', 'Open the booking from Profile > History and follow the cancellation steps shown there.'),
    ('Is my payment information secure?', 'Yes — all payments are processed through encrypted, PCI-compliant channels.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Help and Support',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Need help fast? Our support team usually replies within a few hours.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Frequently Asked Questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          ..._faqs.map((f) => ExpansionTile(
                title: Text(f.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                children: [
                  Text(f.$2, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                ],
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support request sent — we\'ll get back to you by email.')),
              ),
              icon: const Icon(Icons.email_outlined, color: AppColors.primary),
              label: const Text('Contact Support', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
