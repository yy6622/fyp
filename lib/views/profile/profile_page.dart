import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../models/profile_models.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../auth/login_page.dart';
import '../community/create_post_page.dart';
import 'account_setting_page.dart';
import 'chat_setting_page.dart';
// TEMP DEBUG import — delete this line together with dev_seed_page.dart,
// dev_seed_service.dart, and the isFakeSeed rule additions in
// firestore.rules when test data is no longer needed.
import 'dev_seed_page.dart';
import 'friends_page.dart';
import 'help_support_page.dart';
import 'history_page.dart';
import 'privacy_security_page.dart';
import 'report_attraction_page.dart';
import 'select_plan_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileController controller = ProfileController();

  late final List<ProfileMenuItem> _menuItems = [
    ProfileMenuItem(Icons.person_outline, 'Account Setting', () => _push(const AccountSettingPage())),
    ProfileMenuItem(Icons.history, 'History', () => _push(const HistoryPage())),
    ProfileMenuItem(Icons.card_travel_outlined, 'Travel Preferences', () => _push(const SelectPlanPage())),
    ProfileMenuItem(Icons.chat_bubble_outline, 'Chat Setting', () => _push(const ChatSettingPage())),
    ProfileMenuItem(Icons.dynamic_feed_outlined, 'Community Post', () => _push(const CreatePostPage())),
    ProfileMenuItem(Icons.people_outline, 'Friends', () => _push(const FriendsPage())),
    ProfileMenuItem(Icons.privacy_tip_outlined, 'Privacy and Security', () => _push(const PrivacySecurityPage())),
    ProfileMenuItem(Icons.add_location_alt_outlined, 'Report new attraction spot', () => _push(const ReportAttractionPage())),
    ProfileMenuItem(Icons.help_outline, 'Help and Support', () => _push(const HelpSupportPage())),
    // TEMP DEBUG entry — delete this line together with the import above
    // when test data is no longer needed.
    ProfileMenuItem(Icons.bug_report_outlined, 'Debug: Seed Test Data', () => _push(const DevSeedPage())),
  ];

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
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
            onTap: controller.toggleFavorited,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Icon(
                controller.favorited ? Icons.favorite : Icons.favorite_border,
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
    final profile = controller.profile;
    final name = controller.loading ? 'Loading…' : (profile?.name.isNotEmpty == true ? profile!.name : 'Traveller');
    final email = profile?.email ?? (AuthService.instance.currentUser?.email ?? '');
    final phone = (profile?.phone.isNotEmpty ?? false) ? profile!.phone : 'Not set';
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
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.chipGrey,
              backgroundImage: (profile?.avatarUrl.isNotEmpty ?? false) ? NetworkImage(profile!.avatarUrl) : null,
              child: (profile?.avatarUrl.isNotEmpty ?? false) ? null : const Icon(Icons.person, color: AppColors.textGrey, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 13, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 13, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Text(phone, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
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

  Widget _buildMenuTile(ProfileMenuItem item, {required bool showDivider}) {
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
