import 'package:flutter/material.dart';

import 'community.dart';
import 'profile_pages.dart';
import 'theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _favorited = false;

  late final List<_MenuItem> _menuItems = [
    _MenuItem(Icons.person_outline, 'Account Setting', () => _push(const AccountSettingPage())),
    _MenuItem(Icons.history, 'History', () => _push(const HistoryPage())),
    _MenuItem(Icons.card_travel_outlined, 'Travel Preferences', () => _push(const TravelPreferencesPage())),
    _MenuItem(Icons.chat_bubble_outline, 'Chat Setting', () => _push(const ChatSettingPage())),
    _MenuItem(Icons.dynamic_feed_outlined, 'Community Post', () => _push(const CreatePostPage())),
    _MenuItem(Icons.people_outline, 'Friends', () => _push(const FriendsPage())),
    _MenuItem(Icons.privacy_tip_outlined, 'Privacy and Security', () => _push(const PrivacySecurityPage())),
    _MenuItem(Icons.add_location_alt_outlined, 'Report new attraction spot', () => _push(const ReportAttractionPage())),
    _MenuItem(Icons.help_outline, 'Help and Support', () => _push(const HelpSupportPage())),
  ];

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildUserCard(),
            const SizedBox(height: 18),
            _buildMenuCard(),
            const SizedBox(height: 32),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your account and preferences',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => _favorited = !_favorited),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Icon(
                _favorited ? Icons.favorite : Icons.favorite_border,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- User card ----------------
  Widget _buildUserCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alice Tan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.email_outlined, size: 13, color: AppColors.textGrey),
                      SizedBox(width: 6),
                      Text('alicetan123@gmail.com', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.phone_outlined, size: 13, color: AppColors.textGrey),
                      SizedBox(width: 6),
                      Text('+60 12-345 6789', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Menu list ----------------
  Widget _buildMenuCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          children: List.generate(_menuItems.length, (index) {
            final item = _menuItems[index];
            final isLast = index == _menuItems.length - 1;
            return _buildMenuTile(item, showDivider: !isLast);
          }),
        ),
      ),
    );
  }

  Widget _buildMenuTile(_MenuItem item, {required bool showDivider}) {
    return InkWell(
      onTap: item.onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(item.icon, size: 19, color: AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.navy, fontWeight: FontWeight.w500),
                  ),
                ),
                if (item.showChevron) const Icon(Icons.chevron_right, size: 20, color: AppColors.textGrey),
              ],
            ),
          ),
          if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }

  // ---------------- Logout button ----------------
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _confirmLogout(context),
          child: const Text(
            'Log out',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
  _MenuItem(this.icon, this.label, this.onTap, {this.showChevron = true});
}