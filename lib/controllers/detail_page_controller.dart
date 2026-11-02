import 'package:flutter/material.dart';

class DetailPageFlightController extends ChangeNotifier {
  bool _showFareRules = false;
  bool get showFareRules => _showFareRules;

  void setShowFareRules(bool value) {
    _showFareRules = value;
    notifyListeners();
  }
}
