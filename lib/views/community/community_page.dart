import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../theme.dart';
import '../filter/filter_page.dart';
import '../../models/filter_models.dart' as filters;
import 'community_post_detail_page.dart';
import 'create_post_page.dart';
import 'itinerary_select_page.dart';

// ---------------------------------------------------------------------
// Community page — a single feed of travel posts (each post carries its
// own itinerary breakdown + reviews, expandable right on the card).
// ---------------------------------------------------------------------
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final CommunityController controller = CommunityController();

  @override
  void initState() {
    super.initState();
    controller.search.addListener(controller.refreshSearch);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterPage(type: filters.FilterType.plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildStoryBanner(),
                  const SizedBox(height: 14),
                  Expanded(child: _buildFeed()),
                ],
              ),
              if (controller.composeOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => controller.setComposeOpen(false),
                    child: Container(color: Colors.black.withValues(alpha: 0.15)),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: ListenableBuilder(listenable: controller, builder: (context, _) => _buildComposeFab()),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'Community',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ---------------- Search + banner ----------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textGrey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller.search,
                decoration: const InputDecoration(
                  hintText: 'Search post and destination',
                  hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            GestureDetector(
              onTap: _openFilters,
              child: const Icon(Icons.tune, color: AppColors.textGrey, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // Same footprint as a feed post card below (white card, 16 radius,
  // ECECEC border) — just filled with a full-bleed image instead of
  // text content. Drop your own picture in at assets/images/story_banner.jpg
  // (declared in pubspec.yaml's assets/images/ folder already) and it
  // replaces the placeholder automatically; until then AppImage shows a
  // graceful grey placeholder instead of crashing.
  Widget _buildStoryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 260,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppImage('assets/images/story_banner.jpg', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Share your travel story',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Inspire others and unlock your first\nhot travel content.',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _openCreatePost(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF104259), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 13, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Create Post', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Feed ----------------
  Widget _buildFeed() {
    final posts = controller.filteredPosts;
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts match your search', style: TextStyle(color: AppColors.textGrey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, i) => _postCard(posts[i]),
    );
  }

  Widget _postCard(CommunityPost post) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openDetail(post),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: post.avatarColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text('${post.handle} · ${post.timeAgo}', style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textGrey),
                  onPressed: () => _openPostMenu(post),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openDetail(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(post.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                    const SizedBox(width: 6),
                    Text(post.flagEmoji, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(post.description, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.35)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 78,
                  child: Row(
                    children: List.generate(post.images.length.clamp(0, 3), (i) {
                      final isLastVisible = i == 2 && post.images.length > 3;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  post.images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(color: AppColors.chipGrey, child: const Icon(Icons.image_outlined, color: AppColors.textGrey)),
                                ),
                                if (isLastVisible)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    alignment: Alignment.center,
                                    child: Text('+${post.images.length - 3}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 3),
              Text(post.location, style: const TextStyle(fontSize: 11.5, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => controller.toggleLike(post),
                child: Row(
                  children: [
                    Icon(post.liked ? Icons.favorite : Icons.favorite_border,
                        size: 18, color: post.liked ? Colors.redAccent : AppColors.textGrey),
                    const SizedBox(width: 5),
                    Text('${post.likes}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comments are coming soon')),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textGrey),
                    const SizedBox(width: 5),
                    Text('${post.comments}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () => controller.toggleSaved(post),
                child: Row(
                  children: [
                    Icon(post.saved ? Icons.bookmark : Icons.bookmark_border,
                        size: 17, color: post.saved ? AppColors.primary : AppColors.textGrey),
                    const SizedBox(width: 5),
                    const Text('Save', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share link copied')),
                ),
                child: const Icon(Icons.share_outlined, size: 18, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPostMenu(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border, color: AppColors.navy),
              title: Text(post.saved ? 'Remove from saved' : 'Save post'),
              onTap: () {
                controller.toggleSaved(post);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: AppColors.navy),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.navy),
              title: const Text('Report post'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(CommunityPost post) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: post)));
  }

  // ---------------- Compose FAB ----------------
  Widget _buildComposeFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (controller.composeOpen) ...[
          _composeOption('Normal Post', () {
            controller.setComposeOpen(false);
            _openCreatePost();
          }),
          const SizedBox(height: 10),
          _composeOption('Itinerary Post', () {
            controller.setComposeOpen(false);
            _openItinerarySelect();
          }),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: controller.toggleComposeOpen,
          child: Icon(controller.composeOpen ? Icons.close : Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Widget _composeOption(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECECEC)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
      ),
    );
  }

  void _openCreatePost({String? itineraryTitle}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreatePostPage(itineraryTitle: itineraryTitle)),
    );
  }

  void _openItinerarySelect() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ItinerarySelectPage()),
    );
  }
}
