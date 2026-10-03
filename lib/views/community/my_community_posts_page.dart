import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'community_post_detail_page.dart';
import 'create_post_page.dart';

// ---------------------------------------------------------------------
// Profile's "Community Post" entry — a real "My Posts" / "Saved" view
// instead of jumping straight into composing. Backed by the same
// Firestore-backed [CommunityController] stream the Community feed and
// post detail page use, so a like/save/new post made anywhere shows up
// here too without a manual refresh.
// ---------------------------------------------------------------------
class MyCommunityPostsPage extends StatefulWidget {
  const MyCommunityPostsPage({super.key});

  @override
  State<MyCommunityPostsPage> createState() => _MyCommunityPostsPageState();
}

class _MyCommunityPostsPageState extends State<MyCommunityPostsPage> {
  final CommunityController controller = CommunityController();
  int _tabIndex = 0; // 0 = My Posts, 1 = Saved

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Community Post', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final posts = controller.filteredPosts;
          final shown = _tabIndex == 0 ? posts.where((p) => p.authorId == _uid).toList() : posts.where((p) => p.saved).toList();
          return Column(
            children: [
              // Bare, full-bleed PillTabBar directly under the AppBar — same
              // as history_page.dart / community_post_detail_page.dart's
              // tabs. This page used to wrap it in extra 20/14px padding,
              // which both indented the pills and left a visible gap above
              // them that no other PillTabBar page has.
              PillTabBar(
                tabs: const [
                  PillTab('My Posts', Icons.dynamic_feed_outlined),
                  PillTab('Saved', Icons.bookmark_outline),
                ],
                selectedIndex: _tabIndex,
                onSelected: (i) => setState(() => _tabIndex = i),
              ),
              Expanded(
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : shown.isEmpty
                        ? Center(
                            child: Text(
                              _tabIndex == 0 ? "You haven't posted anything yet" : 'No saved posts yet',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) => _postRow(shown[i]),
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostPage())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _postRow(CommunityPost post) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: post))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECECEC))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: post.images.isNotEmpty
                  ? Image.network(
                      post.images.first,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.chipGrey,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: AppColors.textGrey),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: AppColors.chipGrey,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: AppColors.textGrey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 3),
                  Text(post.location.isEmpty ? 'Unknown' : post.location, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(post.liked ? Icons.favorite : Icons.favorite_border, size: 13, color: post.liked ? Colors.redAccent : AppColors.textGrey),
                      const SizedBox(width: 3),
                      Text('${post.likes}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, size: 13, color: AppColors.orange),
                      const SizedBox(width: 3),
                      Text(post.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => controller.toggleSaved(post),
              child: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border, size: 18, color: post.saved ? AppColors.primary : AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
