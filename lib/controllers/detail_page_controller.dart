import 'package:flutter/material.dart';

/// Controller for [DetailPageHotel] (Details / Review tabs).
class DetailPageHotelController extends ChangeNotifier {
  bool _showReview = false;
  bool get showReview => _showReview;

  void setShowReview(bool value) {
    _showReview = value;
    notifyListeners();
  }
}

/// Which tab is showing on the community itinerary detail page.
enum DetailPlanTab { itinerary, media, review }

/// Controller for [DetailPagePlan] (Itinerary / Media / Review tabs).
class DetailPagePlanController extends ChangeNotifier {
  DetailPlanTab _tab = DetailPlanTab.itinerary;
  DetailPlanTab get tab => _tab;

  int? _expandedDay = 0;
  int? get expandedDay => _expandedDay;

  bool _isFollowing = false;
  bool get isFollowing => _isFollowing;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  void setTab(DetailPlanTab tab) {
    _tab = tab;
    notifyListeners();
  }

  void toggleDay(int day) {
    _expandedDay = _expandedDay == day ? null : day;
    notifyListeners();
  }

  void toggleFollowing() {
    _isFollowing = !_isFollowing;
    notifyListeners();
  }

  void toggleSaved() {
    _isSaved = !_isSaved;
    notifyListeners();
  }
}
