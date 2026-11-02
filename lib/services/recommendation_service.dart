import '../repositories/catalog_repository.dart';
import 'opening_hours.dart';


class RecommendationWeights {
  final double preference;
  final double rating;
  final double distance;
  final double budget;
  final double schedule;

  const RecommendationWeights({
    this.preference = 0.30,
    this.rating = 0.25,
    this.distance = 0.20,
    this.budget = 0.15,
    this.schedule = 0.10,
  });

  double get sum => preference + rating + distance + budget + schedule;

  void validate() {
    assert((sum - 1.0).abs() < 0.001, 'RecommendationWeights must sum to 1 (got $sum)');
  }
}

class RecommendationContext {
  final bool Function(CatalogAttraction a) withinBudget;

  final Map<String, int> affinity;

  final bool requireOpenNow;

  final bool requireAccessible;

  final DateTime now;

  RecommendationContext({
    required this.withinBudget,
    required this.affinity,
    required this.requireOpenNow,
    required this.requireAccessible,
    DateTime? now,
  }) : now = now ?? DateTime.now();
}

class AttractionRecommendation {
  const AttractionRecommendation._();

  static bool passesMandatoryConstraints(CatalogAttraction a, RecommendationContext ctx) {
    if (!ctx.withinBudget(a)) return false;
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

  static double ratingScore(CatalogAttraction a) {
    final r = double.tryParse(a.rating);
    if (r == null) return 0.5;
    return (r / 5.0).clamp(0.0, 1.0);
  }

  static double distanceScore(CatalogAttraction a) {
    final km = a.distanceKm;
    if (km == null) return 0.5;
    return 1.0 / (1.0 + km / 10.0);
  }

  static double budgetScore(CatalogAttraction a, RecommendationContext ctx) => ctx.withinBudget(a) ? 1.0 : 0.0;

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
        weights.rating * ratingScore(a) +
        weights.distance * distanceScore(a) +
        weights.budget * budgetScore(a, ctx) +
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
