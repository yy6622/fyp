import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import 'author_profile_page.dart';
import 'community_post_detail_page.dart';
import 'create_post_page.dart';
import 'itinerary_select_page.dart';

class CommunityPage extends StatefulWidget {
  final String? initialTagFilter;
  const CommunityPage({super.key, this.initialTagFilter});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final CommunityController controller = CommunityController();

  String get _myUid => AuthService.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    controller.search.addListener(controller.refreshSearch);
    if (widget.initialTagFilter != null) {
      controller.setActiveTagFilter(widget.initialTagFilter);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final tags = controller.allTags.toList()..sort();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filter Posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.setActiveTagFilter(null);
                          controller.setMinRating(0);
                          setSheetState(() {});
                        },
                        child: const Text('Reset', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Tag', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  if (tags.isEmpty)
                    const Text('No tags on any post yet.', style: TextStyle(fontSize: 12, color: AppColors.textGrey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final selected = controller.activeTagFilter == tag;
                        return GestureDetector(
                          onTap: () {
                            controller.setActiveTagFilter(selected ? null : tag);
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : AppColors.chipGrey,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('#$tag',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.navy)),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 18),
                  const Text('Minimum Rating', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [0.0, 3.5, 4.0, 4.5].map((v) {
                      final selected = controller.minRating == v;
                      final label = v == 0 ? 'Any' : '$v+';
                      return GestureDetector(
                        onTap: () {
                          controller.setMinRating(v);
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : AppColors.chipGrey,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.navy)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
                  Expanded(child: _buildScrollableBody()),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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

  Widget _buildStoryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppImage('assets/images/community.jpg', fit: BoxFit.cover),
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

  Widget _buildTagFilterIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => controller.setActiveTagFilter(null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Showing: #${controller.activeTagFilter}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(width: 6),
                const Icon(Icons.close, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(List<CommunityPost> recommended) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Recommended for you', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recommended.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _recommendedCard(recommended[i]),
          ),
        ),
      ],
    );
  }

  Widget _recommendedCard(CommunityPost post) {
    return GestureDetector(
      onTap: () => _openDetail(post),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: AppColors.primary),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(post.location,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (post.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: post.tags.take(2).map((t) => _tagChip(t, dense: true)).toList(),
              ),
            const Spacer(),
            Row(
              children: [
                Icon(post.liked ? Icons.favorite : Icons.favorite_border, size: 13, color: post.liked ? Colors.redAccent : AppColors.textGrey),
                const SizedBox(width: 4),
                Text('${post.likes}', style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String tag, {bool dense = false}) {
    final active = controller.activeTagFilter == tag;
    return GestureDetector(
      onTap: () => controller.setActiveTagFilter(active ? null : tag),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.chipGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '#$tag',
          style: TextStyle(
            fontSize: dense ? 10 : 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableBody() {
    final posts = controller.filteredPosts;
    final recommended = controller.recommendedPosts;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildSearchBar(),
              if (controller.activeTagFilter != null) ...[
                const SizedBox(height: 10),
                _buildTagFilterIndicator(),
              ],
              const SizedBox(height: 12),
              _buildStoryBanner(),
              if (recommended.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildRecommendedSection(recommended),
              ],
              const SizedBox(height: 14),
            ],
          ),
        ),
        if (posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  controller.search.text.trim().isEmpty
                      ? 'No posts yet — be the first to share a trip!'
                      : 'No posts match your search',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (var i = 0; i < posts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 18),
                  _postCard(posts[i]),
                ],
              ]),
            ),
          ),
      ],
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
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openAuthorProfile(post),
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
                    ],
                  ),
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
                if (post.autoFlagged) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.hourglass_top, size: 13, color: AppColors.orange),
                        SizedBox(width: 6),
                        Text('Pending review — only visible to you until an admin checks it',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.orange)),
                      ],
                    ),
                  ),
                ],
                Text(post.description, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.35)),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: post.tags.map((t) => _tagChip(t)).toList(),
                  ),
                ],
                if (post.hasVideo || post.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 78,
                    child: post.hasVideo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: AppColors.chipGrey,
                              alignment: Alignment.center,
                              child: const Icon(Icons.play_circle_fill, size: 30, color: AppColors.navy),
                            ),
                          )
                        : Row(
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
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 3),
              Expanded(
                child: Text(post.location,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.primary)),
              ),
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
                onTap: () => _openReviews(post),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textGrey),
                    const SizedBox(width: 5),
                    Text('${post.ratingCount}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _sharePost(post),
                child: const Icon(Icons.share_outlined, size: 18, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openReviews(CommunityPost post) {
    controller.setTab(post, CommunityPostTab.review);
    _openDetail(post);
  }

  Future<void> _sharePost(CommunityPost post) async {
    await SharePlus.instance.share(ShareParams(
      text: '${post.title}\n\n${post.description}\n\n— shared from Voya',
      subject: post.title,
    ));
  }

  Future<void> _reportPostFromFeed(CommunityPost post) async {
    final reasonCtrl = TextEditingController();
    final result = await showNiceFormDialog(
      context: context,
      title: 'Report post',
      headerIcon: Icons.flag_outlined,
      confirmLabel: 'Submit report',
      fieldsBuilder: (ctx, setState) => [
        const Text(
          'Let us know what\'s wrong with this post — our team will review it.',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 14),
        niceDialogField(reasonCtrl, 'Reason', autofocus: true),
      ],
    );
    if (result != true) return;
    final reason = reasonCtrl.text.trim();
    if (!mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please tell us the reason for the report')));
      return;
    }
    final error = await controller.reportPost(post, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Thanks — our team will take a look at this post.')),
    );
  }

  Future<void> _deletePostFromFeed(CommunityPost post) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Delete Post',
      message: 'This post will be permanently removed. This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever,
      destructive: true,
    );
    if (!confirmed) return;
    final error = await controller.deletePost(post);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Your post has been deleted.')),
    );
  }

  void _openPostMenu(CommunityPost post) {
    final isMine = post.authorId == _myUid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: isMine
              ? [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: AppColors.navy),
                    title: const Text('Edit Post'),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatePostPage(editingPost: post)));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: const Text('Delete Post', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _deletePostFromFeed(post);
                    },
                  ),
                ]
              : [
                  ListTile(
                    leading: const Icon(Icons.share_outlined, color: AppColors.navy),
                    title: const Text('Share'),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _sharePost(post);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: AppColors.navy),
                    title: const Text('Report post'),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _reportPostFromFeed(post);
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

  void _openAuthorProfile(CommunityPost post) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AuthorProfilePage(authorId: post.authorId, authorName: post.author, avatarColor: post.avatarColor),
    ));
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

  void _openCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
  }

  void _openItinerarySelect() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ItinerarySelectPage()),
    );
  }
}
