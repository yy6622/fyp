import 'package:flutter/material.dart';


enum CommunityPostTab { itinerary, review }

class CommunityItineraryDay {
  final int day;
  final List<String> items;

  final List<ImportableActivity> activities;

  const CommunityItineraryDay({required this.day, required this.items, this.activities = const []});
}

class ImportableActivity {
  final String time;
  final String label;
  final String location;
  final String iconKey;
  const ImportableActivity({required this.time, required this.label, this.location = '', required this.iconKey});
}

class CommunityPost {
  final String id;

  final String authorId;
  final String author;
  final String handle;
  final Color avatarColor;
  final String timeAgo;
  final String title;
  final String flagEmoji;
  final String description;
  final List<String> images;

  final String videoUrl;
  bool get hasVideo => videoUrl.isNotEmpty;

  final String location;
  final List<CommunityItineraryDay> itinerary;
  final double avgRating;
  final int ratingCount;
  int likes;
  int comments;
  bool liked;
  int myRating;

  final int viewCount;

  final int uniqueViewerCount;

  final int reportCount;

  final bool autoFlagged;

  final List<String> tags;

  CommunityPostTab tab;
  int? expandedDay;
  CommunityPost({
    required this.id,
    required this.authorId,
    required this.author,
    required this.handle,
    required this.avatarColor,
    required this.timeAgo,
    required this.title,
    required this.flagEmoji,
    required this.description,
    required this.images,
    this.videoUrl = '',
    required this.location,
    this.itinerary = const [],
    required this.avgRating,
    required this.ratingCount,
    required this.likes,
    required this.comments,
    this.liked = false,
    this.myRating = 0,
    this.viewCount = 0,
    this.uniqueViewerCount = 0,
    this.reportCount = 0,
    this.autoFlagged = false,
    this.tags = const [],
    this.tab = CommunityPostTab.itinerary,
    this.expandedDay = 1,
  });
}

