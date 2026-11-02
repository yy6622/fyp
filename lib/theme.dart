import 'package:flutter/material.dart';

import 'repositories/user_repository.dart';

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

class PillTab {
  final String label;
  final IconData icon;
  const PillTab(this.label, this.icon);
}

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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                  border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.white, width: 2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 15, color: selected ? AppColors.primary : AppColors.textGrey),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey),
                      ),
                    ),
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

class AppAvatar extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final IconData fallbackIcon;
  final double? iconSize;
  final Widget? child;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.backgroundColor = AppColors.chipGrey,
    this.fallbackIcon = Icons.person,
    this.iconSize,
    this.child,
  });

  @override
  State<AppAvatar> createState() => _AppAvatarState();
}

class _AppAvatarState extends State<AppAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant AppAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = (widget.imageUrl ?? '').isNotEmpty && !_failed;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      backgroundImage: hasUrl ? NetworkImage(widget.imageUrl!) : null,
      onBackgroundImageError: hasUrl
          ? (_, __) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: widget.child ?? (hasUrl ? null : Icon(widget.fallbackIcon, size: widget.iconSize ?? widget.radius, color: AppColors.textGrey)),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String uid;
  final double radius;
  final Color backgroundColor;
  const UserAvatar({super.key, required this.uid, required this.radius, this.backgroundColor = AppColors.chipGrey});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return AppAvatar(imageUrl: null, radius: radius, backgroundColor: backgroundColor);
    }
    return StreamBuilder<AppUser?>(
      stream: UserRepository.instance.watchProfile(uid),
      builder: (context, snapshot) {
        return AppAvatar(imageUrl: snapshot.data?.avatarUrl, radius: radius, backgroundColor: backgroundColor);
      },
    );
  }
}
