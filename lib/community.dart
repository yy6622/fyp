import 'package:flutter/material.dart';

import 'detail_pages.dart';
import 'filter.dart' as filters;
import 'theme.dart';

// ---------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------
class _ItineraryPost {
  final String title;
  final String image;
  final String rating;
  final String likes;
  const _ItineraryPost({required this.title, required this.image, required this.rating, required this.likes});
}

const List<_ItineraryPost> _itineraryPosts = [
  _ItineraryPost(
    title: 'New York 7 days 6 night',
    image: 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400',
    rating: '4.8(1.2k)',
    likes: '126',
  ),
  _ItineraryPost(
    title: 'Tokyo 6 Days 5 Nights',
    image: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=400',
    rating: '4.8(1.2k)',
    likes: '126',
  ),
  _ItineraryPost(
    title: 'Seoul 5 Days 4 Nights',
    image: 'https://images.unsplash.com/photo-1517154421773-0529f29ea451?w=400',
    rating: '4.8(1.2k)',
    likes: '126',
  ),
  _ItineraryPost(
    title: 'Paris 7 Days 6 Nights',
    image: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400',
    rating: '4.8(1.2k)',
    likes: '126',
  ),
  _ItineraryPost(
    title: 'Bangkok 4 Days 3 Nights',
    image: 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=400',
    rating: '4.8(1.2k)',
    likes: '126',
  ),
];

class CommunityPost {
  final String author;
  final String handle;
  final Color avatarColor;
  final String timeAgo;
  final String title;
  final String flagEmoji;
  final String description;
  final List<String> images;
  final String location;
  int likes;
  int comments;
  bool liked;
  bool saved;
  CommunityPost({
    required this.author,
    required this.handle,
    required this.avatarColor,
    required this.timeAgo,
    required this.title,
    required this.flagEmoji,
    required this.description,
    required this.images,
    required this.location,
    required this.likes,
    required this.comments,
    this.liked = false,
    this.saved = false,
  });
}

final List<CommunityPost> _mockPosts = [
  CommunityPost(
    author: 'Jamie Lee',
    handle: '@jamieleetravels',
    avatarColor: const Color(0xFFE8A57C),
    timeAgo: '2h ago',
    title: '7 Days in Japan',
    flagEmoji: '🇯🇵',
    description: 'Just got back from an amazing trip to Japan! Here\'s my 7-day itinerary and tips.',
    images: const [
      'https://images.unsplash.com/photo-1522383225653-ed111181a951?w=300',
      'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=300',
      'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=300',
    ],
    location: 'Japan',
    likes: 128,
    comments: 23,
  ),
  CommunityPost(
    author: 'Sarah.W',
    handle: '@sarahwanders',
    avatarColor: const Color(0xFF8CB7E8),
    timeAgo: '5h ago',
    title: 'New York in Autumn',
    flagEmoji: '🇺🇸',
    description: 'Times Square at night is unreal. Sharing my full New York itinerary and budget breakdown.',
    images: const [
      'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=300',
      'https://images.unsplash.com/photo-1522083165195-3424ed129620?w=300',
    ],
    location: 'New York, USA',
    likes: 94,
    comments: 11,
  ),
];

// ---------------------------------------------------------------------
// Community page — two views: Itineraries grid and social Posts feed.
// ---------------------------------------------------------------------
enum CommunityView { itineraries, posts }

class CommunityPage extends StatefulWidget {
  final CommunityView initialView;
  const CommunityPage({super.key, this.initialView = CommunityView.itineraries});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late CommunityView _view = widget.initialView;
  bool _composeOpen = false;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const filters.FilterPage(type: filters.FilterType.plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 6),
                _buildViewSwitch(),
                if (_view == CommunityView.posts) ...[
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildStoryBanner(),
                ],
                const SizedBox(height: 10),
                Expanded(child: _view == CommunityView.itineraries ? _buildItineraryGrid() : _buildFeed()),
              ],
            ),
            if (_composeOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _composeOpen = false),
                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildComposeFab(),
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
          GestureDetector(
            onTap: _openFilters,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.tune, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _viewLabel('Itineraries', CommunityView.itineraries),
        const SizedBox(width: 24),
        _viewLabel('Posts', CommunityView.posts),
      ],
    );
  }

  Widget _viewLabel(String label, CommunityView view) {
    final selected = _view == view;
    return GestureDetector(
      onTap: () => setState(() => _view = view),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? AppColors.navy : AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: 60, color: selected ? AppColors.primary : Colors.transparent),
        ],
      ),
    );
  }

  // ---------------- Itinerary grid ----------------
  Widget _buildItineraryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: _itineraryPosts.length,
      itemBuilder: (context, i) => _itineraryCard(_itineraryPosts[i]),
    );
  }

  Widget _itineraryCard(_ItineraryPost post) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetailPagePlan())),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                post.image,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 110,
                  color: AppColors.chipGrey,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textGrey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: AppColors.orange),
                          const SizedBox(width: 2),
                          Text(post.rating, style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.favorite_border, size: 12, color: AppColors.textGrey),
                          const SizedBox(width: 2),
                          Text(post.likes, style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
                        ],
                      ),
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

  // ---------------- Posts feed ----------------
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
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search post and destination',
                  hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 130,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=600'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.85],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Share your travel story',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Inspire others and make memories\nthat last forever.',
                    style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _openCreatePost(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF5B4FE0), borderRadius: BorderRadius.circular(20)),
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
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final query = _search.text.trim().toLowerCase();
    final posts = query.isEmpty
        ? _mockPosts
        : _mockPosts
            .where((p) =>
                p.title.toLowerCase().contains(query) ||
                p.location.toLowerCase().contains(query) ||
                p.author.toLowerCase().contains(query))
            .toList();
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
          Row(
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
              GestureDetector(
                onTap: () => _showPostMenu(post),
                child: const Icon(Icons.more_vert, size: 18, color: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF0015FF)),
              const SizedBox(width: 3),
              Text(post.location, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0015FF))),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 6),
          Row(
            children: [
              _postAction(
                icon: post.liked ? Icons.favorite : Icons.favorite_border,
                color: post.liked ? Colors.redAccent : AppColors.textGrey,
                label: '${post.likes}',
                onTap: () => setState(() {
                  post.liked = !post.liked;
                  post.likes += post.liked ? 1 : -1;
                }),
              ),
              _postAction(
                icon: Icons.chat_bubble_outline,
                color: AppColors.textGrey,
                label: '${post.comments}',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comments are coming soon')),
                ),
              ),
              _postAction(
                icon: post.saved ? Icons.bookmark : Icons.bookmark_border,
                color: post.saved ? AppColors.primary : AppColors.textGrey,
                label: 'Save',
                onTap: () => setState(() {
                  post.saved = !post.saved;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(post.saved ? 'Saved to your list' : 'Removed from your list')),
                  );
                }),
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

  Widget _postAction({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, color: color == AppColors.textGrey ? AppColors.textGrey : color)),
          ],
        ),
      ),
    );
  }

  void _showPostMenu(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.navy),
              title: const Text('Report post'),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post reported. Thanks for letting us know.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: AppColors.navy),
              title: const Text('Not interested'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Compose FAB ----------------
  Widget _buildComposeFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_composeOpen) ...[
          _composeOption('Normal Post', () {
            setState(() => _composeOpen = false);
            _openCreatePost();
          }),
          const SizedBox(height: 10),
          _composeOption('Itinerary Post', () {
            setState(() => _composeOpen = false);
            _openItinerarySelect();
          }),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () => setState(() => _composeOpen = !_composeOpen),
          child: Icon(_composeOpen ? Icons.close : Icons.add, color: Colors.white),
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

// ---------------------------------------------------------------------
// Create Post ("Community Post" / "Itinerary Post" compose form)
// ---------------------------------------------------------------------
class CreatePostPage extends StatefulWidget {
  final String? itineraryTitle;
  const CreatePostPage({super.key, this.itineraryTitle});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _mediaAdded = false;
  bool _allowComments = true;
  bool _allowShare = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _publish() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a title before publishing')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your post has been published!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isItinerary = widget.itineraryTitle != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: Text(isItinerary ? 'Itinerary Post' : 'Community Post',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (isItinerary) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Linked itinerary: ${widget.itineraryTitle}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _label('Title'),
                const SizedBox(height: 8),
                _textField(_titleCtrl, maxLength: 100),
                const SizedBox(height: 16),
                _label('Description'),
                const SizedBox(height: 8),
                _textField(_descCtrl, maxLength: 500, lines: 4),
                const SizedBox(height: 16),
                _label('Upload Media'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _mediaAdded = !_mediaAdded),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFECECEC)),
                      borderRadius: BorderRadius.circular(10),
                      color: _mediaAdded ? AppColors.chipGrey : Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: _mediaAdded
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('1 photo added — tap to remove', style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                            ],
                          )
                        : const Icon(Icons.file_upload_outlined, color: AppColors.textGrey),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('More Options', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 4),
                _switchRow('Allow comments', _allowComments, (v) => setState(() => _allowComments = v)),
                _switchRow('Allow others to share', _allowShare, (v) => setState(() => _allowShare = v)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _publish,
                child: const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black));

  Widget _textField(TextEditingController ctrl, {required int maxLength, int lines = 1}) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC)));
    return TextField(
      controller: ctrl,
      maxLines: lines,
      maxLength: maxLength,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Itinerary Post — select one of your plans to turn into a post
// ---------------------------------------------------------------------
class _SelectableItinerary {
  final String title;
  final String image;
  final List<String> day1;
  const _SelectableItinerary({required this.title, required this.image, required this.day1});
}

const List<_SelectableItinerary> _myItineraries = [
  _SelectableItinerary(
    title: 'Japan Trips',
    image: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=200',
    day1: ['10:30  Arrive to Narita Airport (NRT)', '14:30  Check-in L Hotel', '16:30  Shibaya Shopping Mall', '19:30  Dinner at Uobei Shibuya'],
  ),
  _SelectableItinerary(
    title: 'Korea Trips',
    image: 'https://images.unsplash.com/photo-1517154421773-0529f29ea451?w=200',
    day1: ['09:00  Arrive Incheon Airport (ICN)', '13:00  Check-in Myeongdong Hotel', '15:30  Namsan Tower', '19:00  Dinner at Myeongdong Street'],
  ),
];

class ItinerarySelectPage extends StatefulWidget {
  const ItinerarySelectPage({super.key});

  @override
  State<ItinerarySelectPage> createState() => _ItinerarySelectPageState();
}

class _ItinerarySelectPageState extends State<ItinerarySelectPage> {
  int? _expanded = 0;
  int? _selected;

  void _continue() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an itinerary to continue')));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CreatePostPage(itineraryTitle: _myItineraries[_selected!].title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Itinerary Post', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Select an itinerary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 14),
                ...List.generate(_myItineraries.length, (i) => _itineraryTile(i)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _continue,
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itineraryTile(int index) {
    final item = _myItineraries[index];
    final expanded = _expanded == index;
    final selected = _selected == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFECECEC), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() {
                _selected = index;
                _expanded = expanded ? null : index;
              }),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(item.image, width: 40, height: 40, fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(width: 40, height: 40, color: AppColors.chipGrey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ),
                    Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textGrey),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Day 1', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 6),
                      ...item.day1.map((line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(line, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0015FF))),
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
