import 'package:flutter/material.dart';

/// Controller for [DetailPageFlight] (Details / Fare Rules tabs). Flights
/// have no review surface anywhere in this app (no reviewable catalog
/// entity — see history_detail_pages.dart's scope note on the same gap),
/// so "Fare Rules" is the second tab here, same Details/X two-tab
/// pattern DetailPageHotel used to have before its own Review tab was
/// removed.
class DetailPageFlightController extends ChangeNotifier {
  bool _showFareRules = false;
  bool get showFareRules => _showFareRules;

  void setShowFareRules(bool value) {
    _showFareRules = value;
    notifyListeners();
  }
}
