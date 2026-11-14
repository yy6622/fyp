/// Maps a trip's declared interest points (CreatePlanWizardController.
/// interestOptions: Beach/City/Nature/Food/Adventure/Culture/Shopping/
/// Nightlife/Relaxation, set at plan creation and editable afterwards
/// from the trip Overview -> TravelPreferencesPage) onto the REAL
/// attraction category tags places are actually stored with (see
/// explore_page.dart's _attractionCategoryBucket doc comment for where
/// that vocabulary comes from -- Geoapify's import or the OSM refresh in
/// catalog_repository.dart).
///
/// 'Food' and 'Nightlife' are deliberately left out: there's no
/// attraction category tag that means either of those (restaurants are a
/// separate recommendation list with cuisine tags, not category tags,
/// and nothing in the catalogue is tagged as a bar/club), so mapping
/// them to an unrelated category would just be a fabricated signal.
const Map<String, List<String>> kInterestToAttractionCategoryTags = {
  'Beach': ['Nature', 'Viewpoint'],
  'City': ['Landmark', 'Attraction'],
  'Nature': ['Nature', 'Viewpoint', 'Zoo'],
  'Adventure': ['Adventure', 'Zoo', 'Theme Park'],
  'Culture': ['Art & Culture', 'Historic Site', 'Artwork', 'Gallery', 'Museum'],
  'Shopping': ['Shopping'],
  'Relaxation': ['Nature', 'Viewpoint'],
};

/// How much a declared-interest tag match is worth, in the same units as
/// CatalogRepository's behavioral affinity counts (a view bumps a tag by
/// +1, a save/favorite by +5 -- see CatalogRepository._favoriteAffinityWeight).
/// Picked so interests alone decide the ranking at cold start (every real
/// affinity count is 0 for a brand-new user) while a handful of real
/// saves/views on a different tag can still outweigh it -- this is the
/// "starts from interest points, shifts toward actual behaviour as it
/// builds up, but never drops the interest points entirely" blend.
const int kInterestAffinityBonus = 4;

/// Returns [affinity] with [kInterestAffinityBonus] added to every
/// category tag any of [interests] maps to. Never mutates [affinity]
/// itself -- it's a live stream's current value (ExploreController's
/// _attractionAffinity) that other code also reads.
Map<String, int> blendInterestsIntoAffinity(Map<String, int> affinity, List<String> interests) {
  if (interests.isEmpty) return affinity;
  final blended = Map<String, int>.from(affinity);
  for (final interest in interests) {
    final tags = kInterestToAttractionCategoryTags[interest];
    if (tags == null) continue;
    for (final tag in tags) {
      blended[tag] = (blended[tag] ?? 0) + kInterestAffinityBonus;
    }
  }
  return blended;
}
