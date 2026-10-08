import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../repositories/community_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../detail/detail_widgets.dart';
import '../shared/nice_dialog.dart';
import 'author_profile_page.dart';

// ---------------------------------------------------------------------
// Community post detail — hero photo carousel, rating, and an
// Itinerary/Review tab pair (mirrors the preview shown on the feed card).
// ---------------------------------------------------------------------
class CommunityPostDetailPage extends StatefulWidget {
  final CommunityPost post;
  const CommunityPostDetailPage({super.key, required this.post});

  @override
  State<CommunityPostDetailPage> createState() => _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  final CommunityController controller = CommunityController();
  final PageController _photoController = PageController();
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    // One view per time this page opens — see CommunityRepository.recordView
    // and the Community Post Analysis Report (admin_web) that reads it.
    controller.recordView(widget.post);
  }

  @override
  void dispose() {
    controller.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _reportPost(CommunityPost post) async {
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
    if (reason.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please tell us the reason for the report')));
      return;
    }
    final error = await controller.reportPost(post, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Thanks — our team will take a look at this post.')),
    );
  }

  // Looks up the live version of this post from the controller's own
  // Firestore-backed stream (falling back to the post passed in, before
  // the first snapshot arrives) so likes/saves/ratings made here — or on
  // the feed page, since both share the same underlying stream — show up
  // immediately instead of only after a manual refresh.
  CommunityPost get _livePost {
    for (final p in controller.filteredPosts) {
      if (p.id == widget.post.id) return p;
    }
    return widget.post;
  }

  String get _myUid => AuthService.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: const Text('Community', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 20)),
        // Reporting your own post doesn't make sense — only shown on
        // someone else's. See _reportPost/CommunityController.reportPost.
        actions: widget.post.authorId == _myUid
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.flag_outlined, color: AppColors.textGrey, size: 20),
                  tooltip: 'Report post',
                  onPressed: () => _reportPost(_livePost),
                ),
              ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        // _livePost is read HERE, inside the builder that actually re-runs
        // when `controller` notifies (a like/rating/review write coming
        // back from Firestore) — it used to be read once in the outer
        // build() instead, which only reruns on this State's own setState
        // (e.g. swiping photos). That meant every tap on Like/Rating here
        // genuinely wrote to Firestore, but this page kept rendering the
        // same stale post it captured on first build, so nothing ever
        // looked like it changed — this is why those controls read as
        // "not working" even though the data was updating underneath.
        builder: (context, _) {
          final post = _livePost;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tapping the author here opens their profile, same as
                  // the feed card — see AuthorProfilePage.
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AuthorProfilePage(authorId: post.authorId, authorName: post.author, avatarColor: post.avatarColor),
                      )),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 18, backgroundColor: post.avatarColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.author, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                Text('${post.handle} · ${post.timeAgo}', style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 12, color: AppColors.orange),
                                    const SizedBox(width: 3),
                                    Text('${post.avgRating.toStringAsFixed(1)} (${_compactCount(post.ratingCount)})',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Only one engagement toggle (like) — see CommunityPost's
                  // doc comment for why the bookmark that used to sit next
                  // to this was dropped.
                  GestureDetector(
                    onTap: () => controller.toggleLike(post),
                    child: Icon(post.liked ? Icons.favorite : Icons.favorite_border,
                        size: 18, color: post.liked ? Colors.redAccent : AppColors.textGrey),
                  ),
                  const SizedBox(width: 4),
                  Text('${post.likes}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  const SizedBox(width: 6),
                  Text(post.flagEmoji, style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(post.description, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4)),
              const SizedBox(height: 14),
              _photoCarousel(post),
              if (post.images.length > 1) ...[
                const SizedBox(height: 8),
                _photoDots(post),
              ],
              const SizedBox(height: 16),
              _tabs(post),
              const SizedBox(height: 14),
              post.tab == CommunityPostTab.itinerary ? _fullItinerary(post) : _fullReviews(post),
            ],
          );
        },
      ),
    );
  }

  Widget _photoCarousel(CommunityPost post) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _photoController,
              onPageChanged: (i) => setState(() => _photoIndex = i),
              itemCount: post.images.length,
              itemBuilder: (context, i) => Image.network(
                post.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (c, e, s) => Container(
                  color: AppColors.chipGrey,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, color: AppColors.textGrey),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
            child: Text('${_photoIndex + 1}/${post.images.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _photoDots(CommunityPost post) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(post.images.length, (i) {
        final active = i == _photoIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // There used to be a standalone "quick rate" star row here, separate
  // from the Review tab's own star picker — two ways to rate the same
  // post read as one too many, and rating alongside a review (see
  // showWriteReviewDialog) already covers "just rating, no comment"
  // since the comment field there is optional. Dropped in favor of that.

  Widget _tabs(CommunityPost post) {
    return PillTabBar(
      tabs: const [
        PillTab('Itinerary', Icons.map_outlined),
        PillTab('Review', Icons.rate_review_outlined),
      ],
      selectedIndex: post.tab == CommunityPostTab.itinerary ? 0 : 1,
      onSelected: (i) => controller.setTab(post, i == 0 ? CommunityPostTab.itinerary : CommunityPostTab.review),
    );
  }

  Widget _fullItinerary(CommunityPost post) {
    if (post.itinerary.isEmpty) {
      return const Text('No itinerary attached yet.', style: TextStyle(fontSize: 12, color: AppColors.textGrey));
    }
    return Column(children: post.itinerary.map((day) => _dayRow(post, day)).toList());
  }

  Widget _dayRow(CommunityPost post, CommunityItineraryDay day) {
    final expanded = post.expandedDay == day.day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            InkWell(
              onTap: () => controller.setExpandedDay(post, day.day),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Day ${day.day}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ),
                    Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
                  ],
                ),
              ),
            ),
            if (expanded && day.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: day.items.map((line) => _itineraryLine(line)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryLine(String line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
            child: Icon(_iconForLine(line), size: 12, color: AppColors.navy),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(line, style: const TextStyle(fontSize: 11.5, color: Colors.black87))),
        ],
      ),
    );
  }

  IconData _iconForLine(String line) {
    final l = line.toLowerCase();
    if (l.contains('airport') || l.contains('arrive') || l.contains('depart')) return Icons.flight_land;
    if (l.contains('hotel') || l.contains('check-in') || l.contains('check in')) return Icons.hotel_outlined;
    if (l.contains('shop') || l.contains('mall')) return Icons.shopping_bag_outlined;
    if (l.contains('dinner') || l.contains('lunch') || l.contains('breakfast') || l.contains('restaurant')) return Icons.restaurant_outlined;
    if (l.contains('tower') || l.contains('temple') || l.contains('park') || l.contains('square')) return Icons.place_outlined;
    return Icons.place_outlined;
  }

  String _compactCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  // Real, Firestore-backed written reviews (`posts/{id}/reviews`) — each
  // one's star rating also feeds the post's `ratings` map (see
  // CommunityRepository.addReview), which is what drives avgRating/
  // myRating now that there's no separate quick-rate widget.
  Widget _fullReviews(CommunityPost post) {
    // Defensive guard: a post with no Firestore id has nowhere to read or
    // write reviews from — calling watchReviews('') throws, so show a
    // friendly message instead of crashing (mirrors DetailPageHotel's
    // handling of a manually-added hotel with no catalog id).
    if (post.id.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: const Text(
          'Reviews aren\'t available for this post yet.',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      );
    }
    return ReviewsSection(
      title: post.title,
      ratingSummary: '${post.avgRating.toStringAsFixed(1)} (${_compactCount(post.ratingCount)})',
      reviewsStream: CommunityRepository.instance.watchReviews(post.id).map((list) => list.map(reviewDataFromPlace).toList()),
      onSubmitReview: ({required authorId, required authorName, required rating, required comment}) => CommunityRepository.instance.addReview(
        post.id,
        authorId: authorId,
        authorName: authorName,
        rating: rating,
        comment: comment,
      ),
    );
  }
}
