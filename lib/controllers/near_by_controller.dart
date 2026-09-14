import 'dart:async';

import 'package:flutter/material.dart';

import '../models/nearby_models.dart';
import '../repositories/catalog_repository.dart';

/// Controller for [NearByPage]. Streams the places catalogue from Firestore
/// (seeded once — see [CatalogRepository]) instead of a hardcoded list.
class NearByController extends ChangeNotifier {
  NearByController() {
    CatalogRepository.instance.seedIfEmpty();
    _resubscribe();
  }

  String _selectedCategory = 'Restaurants';
  String get selectedCategory => _selectedCategory;

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _resubscribe();
    notifyListeners();
  }

  List<NearbyPlace> places = [];
  bool loading = true;

  StreamSubscription<List<NearbyPlace>>? _sub;

  void _resubscribe() {
    _sub?.cancel();
    _sub = CatalogRepository.instance.watchPlaces(category: _selectedCategory).listen((v) {
      places = v;
      loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
