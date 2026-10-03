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

/// Controller for [DetailPageFlight] (Details / Fare Rules tabs) — same
/// idea as [DetailPageHotelController], just named for what flights
/// actually have two of. Flights have no review surface anywhere in this
/// app (no reviewable catalog entity — see history_detail_pages.dart's
/// scope note on the same gap), so "Fare Rules" is the second tab
/// instead of "Review", but the tab bar itself is the same Details/X
/// two-tab pattern every other buy-page detail screen uses.
class DetailPageFlightController extends ChangeNotifier {
  bool _showFareRules = false;
  bool get showFareRules => _showFareRules;

  void setShowFareRules(bool value) {
    _showFareRules = value;
    notifyListeners();
  }
}
