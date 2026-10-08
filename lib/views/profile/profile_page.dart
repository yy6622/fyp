import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../models/profile_models.dart';
import '../../repositories/catalog_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../auth/login_page.dart';
import '../shared/nice_dialog.dart';
import '../community/my_community_posts_page.dart';
import 'account_setting_page.dart';
import 'friends_page.dart';
import 'help_support_page.dart';
import 'history_page.dart';
import 'privacy_security_page.dart';
import 'report_attraction_page.dart';

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
    ProfileMenuItem(Icons.dynamic_feed_outlined, 'Community Post', () => _push(const MyCommunityPostsPage())),
    ProfileMenuItem(Icons.people_outline, 'Friends', () => _push(const FriendsPage())),
    ProfileMenuItem(Icons.privacy_tip_outlined, 'Privacy and Security', () => _push(const PrivacySecurityPage())),
    ProfileMenuItem(Icons.add_location_alt_outlined, 'Report new attraction spot', () => _push(const ReportAttractionPage())),
    ProfileMenuItem(Icons.help_outline, 'Help and Support', () => _push(const HelpSupportPage())),
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
      backgroundColor: AppColors.scaffoldBackground,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
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
            AppAvatar(
              imageUrl: profile?.avatarUrl,
              radius: 32,
              iconSize: 30,
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

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      icon: Icons.logout,
      destructive: true,
    );
    if (!confirmed) return;
    // Belt-and-suspenders: drop this account's in-memory flight/hotel
    // search cache right as it signs out (see CatalogRepository.
    // clearSearchCache's doc comment) before handing off to whoever
    // signs in next on this device.
    CatalogRepository.instance.clearSearchCache();
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
