import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'community_post_detail_page.dart';
import 'create_post_page.dart';

// ---------------------------------------------------------------------
// Profile's "Community Post" entry — a real "My Posts" / "Liked" /
// "Rating & Review" view instead of jumping straight into composing.
// Backed by the same Firestore-backed [CommunityController] stream the
// Community feed and post detail page use, so a like/rating/review made
// anywhere — here, the feed, or a post's own detail page — shows up
// across all of them without a manual refresh.
//
// Liked: posts this user liked (CommunityPost.liked — already resolved
// for the signed-in user when each post snapshot is read). Rating &
// Review: posts they've rated and/or left a written review on — the two
// are the same action now (rating only ever happens as part of leaving a
// review, see showWriteReviewDialog), so one combined tab covers both;
// a post lands here if either CommunityPost.myRating > 0 or it's in
// CommunityController.myReviewedPostIds (a collectionGroup query over
// every post's `reviews` subcollection) — kept as two checks since older
// ratings set before review+rating were merged won't have a review doc.
// ---------------------------------------------------------------------
class MyCommunityPostsPage extends StatefulWidget {
  const MyCommunityPostsPage({super.key});

  @override
  State<MyCommunityPostsPage> createState() => _MyCommunityPostsPageState();
}

class _MyCommunityPostsPageState extends State<MyCommunityPostsPage> {
  final CommunityController controller = CommunityController();
  int _tabIndex = 0; // 0 = My Posts, 1 = Liked, 2 = Rating & Review

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
          final shown = switch (_tabIndex) {
            0 => posts.where((p) => p.authorId == _uid).toList(),
            1 => posts.where((p) => p.liked).toList(),
            _ => posts.where((p) => p.myRating > 0 || controller.myReviewedPostIds.contains(p.id)).toList(),
          };
          final emptyMessage = switch (_tabIndex) {
            0 => "You haven't posted anything yet",
            1 => "You haven't liked any posts yet",
            _ => "You haven't rated or reviewed any posts yet",
          };
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
                  PillTab('Liked', Icons.favorite_border),
                  PillTab('Rating & Review', Icons.reviews_outlined),
                ],
                selectedIndex: _tabIndex,
                onSelected: (i) => setState(() => _tabIndex = i),
              ),
              Expanded(
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : shown.isEmpty
                        ? Center(
                            child: Text(emptyMessage, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
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
    final reviewed = controller.myReviewedPostIds.contains(post.id);
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
                  if (post.myRating > 0 || reviewed) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (post.myRating > 0) _youBadge(Icons.star, 'You rated ${post.myRating}★'),
                        if (reviewed) _youBadge(Icons.chat_bubble_outline, 'You reviewed'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _youBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }
}
