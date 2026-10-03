import 'package:flutter/material.dart';

/// Shared color palette for the whole app, pulled from the Figma design.
class AppColors {
  // Main Color
  static const primary = Color(0xFF104259);
  static const navy = Color(0xFF104259);
  static const navyLight = Color(0xFF104259);
  static const teal = Color(0xFF104259);

  // Secondary
  static const orange = Color(0xFFF4A94A);

  // Button / Chip Background
  static const chipGrey = Color(0xFFF4F4F4);

  // Secondary Text
  static const textGrey = Color(0xFF747474);

  // AI Banner
  static const gradientStart = Color(0xFF3A8DDE);
  static const gradientEnd = Color(0xFF6C63FF);

  // Surfaces / borders
  static const scaffoldBackground = Color(0xFFF7F8FA);
  static const border = Color(0xFFECECEC);
  static const divider = Color(0xFFE7E9EE);
}

/// The standard sub-page header used across the app: white background, a
/// centered bold navy title, a navy back arrow, and a thin divider line
/// along the bottom edge (matches the Figma reference for pages like
/// Insurance, History, Group Setting, etc.). Pass the same `title`/`actions`
/// you would give a plain [AppBar] — this just adds the shared chrome.
class VoyaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const VoyaAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: centerTitle,
        leading: leading,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: title,
        actions: actions,
      ),
    );
  }
}

/// The top-right circular icon button used in every top-level page's
/// header (Home/Explore/Plan/Profile) — a solid navy circle with a small
/// white icon centered in it. Pulled out as one shared widget so the four
/// pages can't quietly drift back to different sizes: before this, Home
/// had no circle at all (just a bare 29x29 image), Plan's circle was 44px
/// with a default-size (24px) icon, and Explore/Profile already matched
/// each other at 40px/18px — this is that matching size, now shared.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const HeaderIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// One tab's label + icon for [PillTabBar].
class PillTab {
  final String label;
  final IconData icon;
  const PillTab(this.label, this.icon);
}

/// The full-width, icon-plus-label tab row used on Group Trip's Plan/Chat/
/// Expenses/Vote bar — pulled out as a shared widget so every other tabbed
/// page (Community post detail's Itinerary/Review, History's Flight/Hotel/
/// Insurance, a past booking's Detail/People/Documents/Review) can use the
/// exact same look instead of each rolling its own plain text-underline
/// tabs. Matches the Figma tab bar exactly: each tab is a white pill whose
/// TOP corners are square and BOTTOM corners are rounded (10px), so its 2px
/// bottom border traces a little upward curve at each end instead of a flat
/// line. Only the selected tab's bottom border is navy; the others have an
/// (invisible) white bottom border of the same width, so the curved shape
/// is there for all of them but only the selected one's curve is visible.
class PillTabBar extends StatelessWidget {
  final List<PillTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PillTabBar({super.key, required this.tabs, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final tab = tabs[i];
        final selected = i == selectedIndex;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                  border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.white, width: 2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 15, color: selected ? AppColors.primary : AppColors.textGrey),
                    const SizedBox(width: 5),
                    Text(tab.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Drop-in replacement for `Image.asset` that shows a neutral placeholder
/// instead of a raw exception overlay if the asset ever fails to decode.
class AppImage extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const AppImage(this.asset, {super.key, this.width, this.height, this.fit});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: AppColors.chipGrey,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textGrey, size: 20),
      ),
    );
  }
}
