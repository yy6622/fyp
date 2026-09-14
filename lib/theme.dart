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
