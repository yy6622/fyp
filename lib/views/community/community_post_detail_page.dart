import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../repositories/community_repository.dart';
import '../../theme.dart';
import '../detail/detail_widgets.dart';

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
  void dispose() {
    controller.dispose();
    _photoController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final post = _livePost;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Community', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
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
                GestureDetector(
                  onTap: () => controller.toggleSaved(post),
                  child: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18, color: post.saved ? AppColors.primary : AppColors.textGrey),
                ),
                const SizedBox(width: 10),
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
            _ratingRow(post),
            const SizedBox(height: 14),
            _tabs(post),
            const SizedBox(height: 14),
            post.tab == CommunityPostTab.itinerary ? _fullItinerary(post) : _fullReviews(post),
          ],
        ),
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

  Widget _ratingRow(CommunityPost post) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.star, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How would you rate this post?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                SizedBox(height: 2),
                Text('Your rating helps others find great travel ideas!', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
              ],
            ),
          ),
          ...List.generate(5, (i) {
            final filled = i < post.myRating;
            return GestureDetector(
              onTap: () => controller.setRating(post, i + 1),
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(filled ? Icons.star : Icons.star_border, size: 18, color: filled ? AppColors.orange : AppColors.textGrey),
              ),
            );
          }),
        ],
      ),
    );
  }

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

  // Real, Firestore-backed written reviews (`posts/{id}/reviews`) —
  // separate from the quick 1-tap star rating above (`_ratingRow`, backed
  // by the post's `ratings` map). [CommunityPost.reviews]/[CommunityReview]
  // predate this and are always empty; nothing reads them anymore.
  Widget _fullReviews(CommunityPost post) {
    // Defensive guard: a post with no Firestore id (e.g. sample/demo data
    // that was never saved) has nowhere to read or write reviews from —
    // calling watchReviews('') throws, so show a friendly message instead
    // of crashing (mirrors DetailPageHotel's handling of a manually-added
    // hotel with no catalog id).
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
