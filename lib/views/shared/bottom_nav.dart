import 'package:flutter/material.dart';

import '../../controllers/bottom_nav_controller.dart';
import '../../theme.dart';
import '../explore/explore_page.dart';
import '../home/home_page.dart';
import '../plan/plan_page.dart';
import '../profile/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final BottomNavController controller = BottomNavController();

  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    PlanPage(),
    ProfilePage(),
  ];

  static const _icons = [
    'assets/images/nav_home.png',
    'assets/images/nav_compass.png',
    'assets/images/nav_plan.png',
    'assets/images/nav_account.png',
  ];
  static const _labels = ['Home', 'Explore', 'Plan', 'Profile'];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: controller.index,
            children: _pages,
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  // IMPORTANT: don't give this a fixed total `height`. The bar must size
  // itself to its content (icon + optional label + padding) and let the
  // bottom safe-area inset (gesture bar / nav bar) add on *top* of that,
  // otherwise devices with a tall inset (or the label appearing on the
  // selected tab) push the content past a fixed height and Flutter
  // reports a bottom overflow.
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(4, (i) => _navItem(i)),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    final selected = controller.index == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.setIndex(index),
        child: Container(
          color: selected ? AppColors.primary : Colors.white,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  selected ? Colors.white : AppColors.primary,
                  BlendMode.srcIn,
                ),
                child: AppImage(_icons[index], width: 22, height: 22),
              ),
              if (selected) ...[
                const SizedBox(height: 3),
                Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
