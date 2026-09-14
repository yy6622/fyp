import 'package:flutter/material.dart';

// ---------------------------------------------------------------------
// Mock data for the Community page
// ---------------------------------------------------------------------

/// Which sub-tab of a [CommunityPost]'s itinerary section is showing —
/// used both on the feed card and the full post detail page.
enum CommunityPostTab { itinerary, review }

/// One day inside a [CommunityPost]'s attached itinerary.
class CommunityItineraryDay {
  final int day;
  final List<String> items;
  const CommunityItineraryDay({required this.day, required this.items});
}

/// A single review left on a [CommunityPost].
class CommunityReview {
  final String author;
  final int stars;
  final String text;
  const CommunityReview({required this.author, required this.stars, required this.text});
}

/// A social post in the Community feed. Mutable — likes/comments/liked/saved/
/// myRating/tab/expandedDay all change as the user interacts with it.
class CommunityPost {
  /// Firestore document id — empty for posts that haven't been saved yet.
  final String id;

  /// uid of the post's author — used to check ownership, e.g. for delete.
  final String authorId;
  final String author;
  final String handle;
  final Color avatarColor;
  final String timeAgo;
  final String title;
  final String flagEmoji;
  final String description;
  final List<String> images;
  final String location;
  final List<CommunityItineraryDay> itinerary;
  final List<CommunityReview> reviews;
  final double avgRating;
  final int ratingCount;
  int likes;
  int comments;
  bool liked;
  bool saved;
  int myRating;
  CommunityPostTab tab;
  int? expandedDay;
  CommunityPost({
    this.id = '',
    this.authorId = '',
    required this.author,
    required this.handle,
    required this.avatarColor,
    required this.timeAgo,
    required this.title,
    required this.flagEmoji,
    required this.description,
    required this.images,
    required this.location,
    this.itinerary = const [],
    this.reviews = const [],
    this.avgRating = 4.8,
    this.ratingCount = 1200,
    required this.likes,
    required this.comments,
    this.liked = false,
    this.saved = false,
    this.myRating = 0,
    this.tab = CommunityPostTab.itinerary,
    this.expandedDay = 1,
  });
}

final List<CommunityPost> mockCommunityPosts = [
  CommunityPost(
    author: 'Jamie Lee',
    handle: '@jamieleetravels',
    avatarColor: const Color(0xFFE8A57C),
    timeAgo: '2h ago',
    title: '7 Days in Japan',
    flagEmoji: '🇯🇵',
    description: 'Just got back from an amazing trip to Japan! Here\'s my 7-day itinerary and tips. Tokyo, Kyoto, Osaka and more!',
    images: const [
      'https://images.unsplash.com/photo-1522383225653-ed111181a951?w=600',
      'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600',
      'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=600',
      'https://images.unsplash.com/photo-1493780474015-ba834fd0ce2f?w=600',
    ],
    location: 'Japan',
    likes: 128,
    comments: 23,
    itinerary: const [
      CommunityItineraryDay(day: 1, items: [
        '10:30  Arrive to Narita Airport (NRT)',
        '14:30  Check-in L Hotel',
        '16:30  Shibaya Shopping Mall',
        '19:30  Dinner at Uobei Shibuya',
      ]),
      CommunityItineraryDay(day: 2, items: []),
      CommunityItineraryDay(day: 3, items: []),
      CommunityItineraryDay(day: 4, items: []),
    ],
    reviews: const [
      CommunityReview(
        author: 'Vivi',
        stars: 5,
        text: 'This room was clean and spacious and the air conditioning was cold enough.',
      ),
      CommunityReview(
        author: 'Vivi',
        stars: 5,
        text: 'This room was clean and spacious and the air conditioning was cold enough.',
      ),
    ],
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
      'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=600',
      'https://images.unsplash.com/photo-1522083165195-3424ed129620?w=600',
    ],
    location: 'New York, USA',
    likes: 94,
    comments: 11,
    itinerary: const [
      CommunityItineraryDay(day: 1, items: [
        '09:00  Arrive at JFK Airport',
        '13:00  Check-in Midtown Hotel',
        '16:00  Times Square',
        '19:30  Dinner in Little Italy',
      ]),
      CommunityItineraryDay(day: 2, items: []),
    ],
    reviews: const [
      CommunityReview(author: 'Marcus', stars: 4, text: 'Great itinerary, very walkable and well paced.'),
    ],
  ),
];

/// One of the current user's own itineraries, offered when composing an
/// "Itinerary Post". [days] holds one entry per day of the trip — an empty
/// list for a day with no activities planned yet.
class SelectableItinerary {
  final String title;
  final String image;
  final List<List<String>> days;
  const SelectableItinerary({required this.title, required this.image, required this.days});
}

const List<SelectableItinerary> myItineraries = [
  SelectableItinerary(
    title: 'Japan Trips',
    image: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=200',
    days: [
      ['10:30  Arrive to Narita Airport (NRT)', '14:30  Check-in L Hotel', '16:30  Shibaya Shopping Mall', '19:30  Dinner at Uobei Shibuya'],
      [],
      [],
      [],
    ],
  ),
  SelectableItinerary(
    title: 'Korea Trips',
    image: 'https://images.unsplash.com/photo-1517154421773-0529f29ea451?w=200',
    days: [
      ['09:00  Arrive Incheon Airport (ICN)', '13:00  Check-in Myeongdong Hotel', '15:30  Namsan Tower', '19:00  Dinner at Myeongdong Street'],
      [],
    ],
  ),
];
