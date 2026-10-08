import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'community_post_detail_page.dart';

// ---------------------------------------------------------------------
// Opened by tapping a Community post's author (feed card or the post
// detail page) — that author's own profile, scoped to what's relevant
// from here: the trips they've posted. Gated by that person's own
// Privacy and Security > Public Profile switch (see
// PrivacySecurityController / AppUser.publicProfile): off, and this page
// shows nothing but a plain "this user's profile is private" notice,
// same as any social app's profile-privacy gate. Viewing your OWN name
// always shows your posts regardless of that switch — there's nothing to
// hide from yourself, and this doubles as another way into the same list
// MyCommunityPostsPage's "My Posts" tab shows.
// ---------------------------------------------------------------------
class AuthorProfilePage extends StatefulWidget {
  final String authorId;
  final String authorName;
  final Color avatarColor;
  const AuthorProfilePage({
    super.key,
    required this.authorId,
    required this.authorName,
    required this.avatarColor,
  });

  @override
  State<AuthorProfilePage> createState() => _AuthorProfilePageState();
}

class _AuthorProfilePageState extends State<AuthorProfilePage> {
  final CommunityController controller = CommunityController();
  AppUser? _author;
  bool _loadingAuthor = true;

  bool get _isMe => widget.authorId.isNotEmpty && widget.authorId == (AuthService.instance.currentUser?.uid ?? '');

  @override
  void initState() {
    super.initState();
    UserRepository.instance.fetchProfile(widget.authorId).then((user) {
      if (!mounted) return;
      setState(() {
        _author = user;
        _loadingAuthor = false;
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = _isMe || (_author?.publicProfile ?? true);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(widget.authorName, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _loadingAuthor
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _header(),
                const Divider(height: 1, color: Color(0xFFECECEC)),
                Expanded(child: isPublic ? _posts() : _privateNotice()),
              ],
            ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(radius: 28, backgroundColor: widget.avatarColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.authorName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
                if ((_author?.country ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 13, color: AppColors.textGrey),
                      const SizedBox(width: 3),
                      Text(_author!.country, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _privateNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 36, color: AppColors.textGrey),
            const SizedBox(height: 12),
            Text(
              '${widget.authorName} has set their profile to private',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posts() {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final posts = controller.filteredPosts.where((p) => p.authorId == widget.authorId).toList();
        if (posts.isEmpty) {
          return Center(
            child: Text(
              _isMe ? "You haven't posted anything yet" : "${widget.authorName} hasn't posted anything yet",
              style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _postRow(posts[i]),
        );
      },
    );
  }

  // Same card shape as MyCommunityPostsPage's own post row (thumbnail +
  // title/location/like+rating) — kept as its own small copy here rather
  // than factored out, since the two pages' rows are only coincidentally
  // identical today and starting a shared widget on this one touch point
  // risks drifting the existing, working page for a style change that
  // belongs to this page alone.
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
          ],
        ),
      ),
    );
  }
}
