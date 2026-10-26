import '../repositories/catalog_repository.dart';
import 'opening_hours.dart';

// ---------------------------------------------------------------------
// AI-Based Attraction Recommendation Algorithm (FYP documentation):
//
//   Score(a) = wp·P(a) + wr·R(a) + wd·D(a) + wb·B(a) + wt·T(a)
//
// where P = preference match, R = normalised rating, D = inverse-
// distance, B = budget compatibility, T = operating-hour/schedule
// compatibility, and the weights sum to 1. Mandatory constraints
// (budget, accessibility, operating hours) are checked BEFORE ranking —
// a place that fails one is dropped outright, never merely scored low.
//
// Every factor below is in [0, 1]. Where the underlying data is simply
// missing (no distance measured yet, an un-rated "New" place, no
// parseable opening hours), the factor returns a neutral 0.5 rather
// than 0 or 1 — an unmeasured attraction shouldn't be shoved to the
// bottom (or the top) of the list purely for lacking data, the same
// fail-open stance opening_hours.dart documents for its own unknowns.
// ---------------------------------------------------------------------

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

  /// Asserts the weights sum to 1 (within floating-point tolerance) —
  /// the documented algorithm's own requirement. Call this once when
  /// constructing a non-default set of weights (e.g. from a future
  /// settings screen); the default weights above already satisfy it.
  void validate() {
    assert((sum - 1.0).abs() < 0.001, 'RecommendationWeights must sum to 1 (got $sum)');
  }
}

/// The inputs this algorithm needs beyond what's already on a
/// [CatalogAttraction] — the mandatory constraints and the moment to
/// evaluate "open now" against all come from the caller (Explore's
/// current filter selection), not from the attraction itself.
class RecommendationContext {
  /// Required for the budget mandatory-constraint/B(a) score. Null (or
  /// a selection of 'Any') means no budget constraint is active — B(a)
  /// is then always 1.0 and nothing is dropped for price.
  final bool Function(CatalogAttraction a) withinBudget;

  /// Highest affinity score anywhere in the current candidate set (see
  /// [AttractionRecommendation.rank]) — P(a) is normalised against this
  /// so it always lands in [0, 1] regardless of the affinity map's
  /// absolute scale.
  final Map<String, int> affinity;

  /// Whether "open now" is a mandatory constraint right now (the
  /// person turned the Explore filter's "Open now" switch on).
  final bool requireOpenNow;

  /// Whether "wheelchair accessible" is a mandatory constraint right
  /// now (the person turned the Explore filter's "Wheelchair
  /// accessible" switch on).
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

  /// Step 1 of the documented algorithm: drop anything that fails a
  /// mandatory constraint before it's ever scored or ranked.
  static bool passesMandatoryConstraints(CatalogAttraction a, RecommendationContext ctx) {
    if (!ctx.withinBudget(a)) return false;
    if (ctx.requireAccessible && !a.facilities.contains('Wheelchair accessible')) return false;
    if (ctx.requireOpenNow) {
      final open = isOpenNow(a.openingHours, now: ctx.now);
      // Only a CONFIRMED "closed" excludes a place here — an opening
      // hours string this parser can't read (null) isn't treated as a
      // violation, since that would punish missing OSM data as if it
      // were a known-bad answer.
      if (open == false) return false;
    }
    return true;
  }

  /// P(a) — preference match, from the category-affinity map Explore
  /// already builds from views/favorites (see
  /// CatalogRepository.watchAttractionCategoryAffinity). Normalised
  /// against [maxAffinity] (the highest score anywhere in the current
  /// candidate set) so it's always in [0, 1]; 0.5 (neutral) when there's
  /// no affinity signal at all yet.
  static double preferenceScore(CatalogAttraction a, Map<String, int> affinity, int maxAffinity) {
    if (affinity.isEmpty || maxAffinity <= 0) return 0.5;
    var raw = 0;
    for (final tag in a.categoryTags) {
      raw += affinity[tag] ?? 0;
    }
    return (raw / maxAffinity).clamp(0.0, 1.0);
  }

  /// R(a) — normalised rating. [CatalogAttraction.rating] is a free-text
  /// field ("4.5", or "New" for anything with no reviews yet) rather
  /// than a number, so an unparseable value is genuinely unrated, not
  /// malformed data — scored neutral (0.5) rather than 0, so a brand
  /// new (but otherwise well-matched) place isn't buried under every
  /// mediocre 2-star one.
  static double ratingScore(CatalogAttraction a) {
    final r = double.tryParse(a.rating);
    if (r == null) return 0.5;
    return (r / 5.0).clamp(0.0, 1.0);
  }

  /// D(a) — inverse distance. Smoothly decaying rather than a hard
  /// cutoff: 0 km -> 1.0, 10 km -> 0.5, 30 km -> 0.25, and so on. Null
  /// (not measured — see [AttractionData.distanceKm]'s doc comment)
  /// scores neutral rather than 0, so older rows aren't penalised for
  /// data they predate.
  static double distanceScore(CatalogAttraction a) {
    final km = a.distanceKm;
    if (km == null) return 0.5;
    return 1.0 / (1.0 + km / 10.0);
  }

  /// B(a) — budget compatibility. The mandatory constraint already
  /// decides pass/fail (see [passesMandatoryConstraints]); once a place
  /// has passed, it's fully compatible by definition, so this is binary
  /// rather than a separate partial-credit curve — avoids maintaining
  /// two different notions of "fits the budget" that could disagree
  /// with each other.
  static double budgetScore(CatalogAttraction a, RecommendationContext ctx) => ctx.withinBudget(a) ? 1.0 : 0.0;

  /// T(a) — operating-hour/schedule compatibility. Mirrors
  /// [budgetScore]'s "unknown is neutral" stance: confirmed open -> 1.0,
  /// confirmed closed -> 0.0, can't tell from this place's opening-hours
  /// string -> 0.5.
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

  /// Filters [candidates] by the mandatory constraints and returns the
  /// survivors sorted by [score], highest first — a stable sort (ties
  /// keep their original relative order), same stability guarantee
  /// ExploreController's plain affinity sort already gives, so a
  /// re-rank doesn't visibly shuffle places the algorithm has no real
  /// preference between.
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
