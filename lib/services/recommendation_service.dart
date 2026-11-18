import '../models/duffel_models.dart';
import '../repositories/catalog_repository.dart';
import 'opening_hours.dart';


class RecommendationWeights {
  final double preference;
  final double distance;
  final double schedule;

  const RecommendationWeights({
    this.preference = 0.50,
    this.distance = 0.33,
    this.schedule = 0.17,
  });

  double get sum => preference + distance + schedule;

  void validate() {
    assert((sum - 1.0).abs() < 0.001, 'RecommendationWeights must sum to 1 (got $sum)');
  }
}

class RecommendationContext {
  final Map<String, int> affinity;

  final bool requireOpenNow;

  final bool requireAccessible;

  final DateTime now;

  RecommendationContext({
    required this.affinity,
    required this.requireOpenNow,
    required this.requireAccessible,
    DateTime? now,
  }) : now = now ?? DateTime.now();
}

class AttractionRecommendation {
  const AttractionRecommendation._();

  static bool passesMandatoryConstraints(CatalogAttraction a, RecommendationContext ctx) {
    if (ctx.requireAccessible && !a.facilities.contains('Wheelchair accessible')) return false;
    if (ctx.requireOpenNow) {
      final open = isOpenNow(a.openingHours, now: ctx.now);
      if (open == false) return false;
    }
    return true;
  }

  static double preferenceScore(CatalogAttraction a, Map<String, int> affinity, int maxAffinity) {
    if (affinity.isEmpty || maxAffinity <= 0) return 0.5;
    var raw = 0;
    for (final tag in a.categoryTags) {
      raw += affinity[tag] ?? 0;
    }
    return (raw / maxAffinity).clamp(0.0, 1.0);
  }

  static double distanceScore(CatalogAttraction a) {
    final km = a.distanceKm;
    if (km == null) return 0.5;
    return 1.0 / (1.0 + km / 10.0);
  }

  static double scheduleScore(CatalogAttraction a, RecommendationContext ctx) {
    final open = isOpenNow(a.openingHours, now: ctx.now);
    if (open == null) return 0.5;
    return open ? 1.0 : 0.0;
  }

  static double score(
    CatalogAttraction a,
    RecommendationContext ctx, {
    int maxAffinity = 0,
    RecommendationWeights weights = const RecommendationWeights(),
  }) {
    return weights.preference * preferenceScore(a, ctx.affinity, maxAffinity) +
        weights.distance * distanceScore(a) +
        weights.schedule * scheduleScore(a, ctx);
  }

  static List<CatalogAttraction> rank(
    List<CatalogAttraction> candidates,
    RecommendationContext ctx, {
    RecommendationWeights weights = const RecommendationWeights(),
  }) {
    final survivors = candidates.where((a) => passesMandatoryConstraints(a, ctx)).toList();
    final maxAffinity = ctx.affinity.values.fold<int>(0, (m, v) => v > m ? v : m);
    final indexed = survivors.asMap().entries.toList()
      ..sort((x, y) {
        final sx = score(x.value, ctx, maxAffinity: maxAffinity, weights: weights);
        final sy = score(y.value, ctx, maxAffinity: maxAffinity, weights: weights);
        final cmp = sy.compareTo(sx);
        return cmp != 0 ? cmp : x.key.compareTo(y.key);
      });
    return indexed.map((e) => e.value).toList();
  }
}

class RestaurantRecommendationContext {
  final Map<String, int> affinity;

  final DateTime now;

  RestaurantRecommendationContext({
    required this.affinity,
    DateTime? now,
  }) : now = now ?? DateTime.now();
}

class RestaurantRecommendation {
  const RestaurantRecommendation._();

  static double preferenceScore(CatalogRestaurant r, Map<String, int> affinity, int maxAffinity) {
    if (affinity.isEmpty || maxAffinity <= 0) return 0.5;
    var raw = 0;
    for (final tag in r.cuisineTags) {
      raw += affinity[tag] ?? 0;
    }
    return (raw / maxAffinity).clamp(0.0, 1.0);
  }

  static double distanceScore(CatalogRestaurant r) {
    final km = r.distanceKm;
    if (km == null) return 0.5;
    return 1.0 / (1.0 + km / 10.0);
  }

  /// Soft signal only — there's no "open now" toggle for restaurants to
  /// hard-gate on, but a currently-open place is still a better suggestion
  /// than a closed one right now, so it nudges the ranking instead.
  static double scheduleScore(CatalogRestaurant r, RestaurantRecommendationContext ctx) {
    final open = isOpenNow(r.openingHours, now: ctx.now);
    if (open == null) return 0.5;
    return open ? 1.0 : 0.0;
  }

  static double score(
    CatalogRestaurant r,
    RestaurantRecommendationContext ctx, {
    int maxAffinity = 0,
    RecommendationWeights weights = const RecommendationWeights(),
  }) {
    return weights.preference * preferenceScore(r, ctx.affinity, maxAffinity) +
        weights.distance * distanceScore(r) +
        weights.schedule * scheduleScore(r, ctx);
  }

  static List<CatalogRestaurant> rank(
    List<CatalogRestaurant> candidates,
    RestaurantRecommendationContext ctx, {
    RecommendationWeights weights = const RecommendationWeights(),
  }) {
    final maxAffinity = ctx.affinity.values.fold<int>(0, (m, v) => v > m ? v : m);
    final indexed = candidates.asMap().entries.toList()
      ..sort((x, y) {
        final sx = score(x.value, ctx, maxAffinity: maxAffinity, weights: weights);
        final sy = score(y.value, ctx, maxAffinity: maxAffinity, weights: weights);
        final cmp = sy.compareTo(sx);
        return cmp != 0 ? cmp : x.key.compareTo(y.key);
      });
    return indexed.map((e) => e.value).toList();
  }
}

class HotelRecommendationWeights {
  final double preference;
  final double rating;
  final double budget;

  const HotelRecommendationWeights({
    this.preference = 0.40,
    this.rating = 0.35,
    this.budget = 0.25,
  });

  double get sum => preference + rating + budget;

  void validate() {
    assert((sum - 1.0).abs() < 0.001, 'HotelRecommendationWeights must sum to 1 (got $sum)');
  }
}

class HotelRecommendationContext {
  final bool Function(DuffelStayResult h) withinBudget;

  final Map<String, int> affinity;

  const HotelRecommendationContext({
    required this.withinBudget,
    required this.affinity,
  });
}

class HotelRecommendation {
  const HotelRecommendation._();

  static bool passesMandatoryConstraints(DuffelStayResult h, HotelRecommendationContext ctx) => ctx.withinBudget(h);

  static double preferenceScore(DuffelStayResult h, Map<String, int> affinity, int maxAffinity) {
    if (affinity.isEmpty || maxAffinity <= 0) return 0.5;
    var raw = 0;
    for (final tag in h.amenities) {
      raw += affinity[tag] ?? 0;
    }
    return (raw / maxAffinity).clamp(0.0, 1.0);
  }

  static double ratingScore(DuffelStayResult h) {
    final effective = h.reviewScore != null ? h.reviewScore! / 2 : h.rating;
    if (effective == null) return 0.5;
    return (effective / 5.0).clamp(0.0, 1.0);
  }

  static double budgetScore(DuffelStayResult h, HotelRecommendationContext ctx) => ctx.withinBudget(h) ? 1.0 : 0.0;

  static double score(
    DuffelStayResult h,
    HotelRecommendationContext ctx, {
    int maxAffinity = 0,
    HotelRecommendationWeights weights = const HotelRecommendationWeights(),
  }) {
    return weights.preference * preferenceScore(h, ctx.affinity, maxAffinity) +
        weights.rating * ratingScore(h) +
        weights.budget * budgetScore(h, ctx);
  }

  static List<DuffelStayResult> rank(
    List<DuffelStayResult> candidates,
    HotelRecommendationContext ctx, {
    HotelRecommendationWeights weights = const HotelRecommendationWeights(),
  }) {
    final survivors = candidates.where((h) => passesMandatoryConstraints(h, ctx)).toList();
    final maxAffinity = ctx.affinity.values.fold<int>(0, (m, v) => v > m ? v : m);
    final indexed = survivors.asMap().entries.toList()
      ..sort((x, y) {
        final sx = score(x.value, ctx, maxAffinity: maxAffinity, weights: weights);
        final sy = score(y.value, ctx, maxAffinity: maxAffinity, weights: weights);
        final cmp = sy.compareTo(sx);
        return cmp != 0 ? cmp : x.key.compareTo(y.key);
      });
    return indexed.map((e) => e.value).toList();
  }
}

