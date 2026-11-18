const Map<String, List<String>> kInterestToAttractionCategoryTags = {
  // Every tag below is a real admin/attraction-form.html
  // CATEGORY_TAG_PRESETS entry. Earlier versions of this map also listed
  // 'Nature', 'Attraction', 'Shopping', 'Adventure', 'Artwork' and
  // 'Gallery' as tags -- none of those exist as real presets, so they
  // could never actually match a real attraction and were silently dead
  // weight. Removed. 'Shopping' interest is gone entirely: its only tag
  // was the phantom 'Shopping' string, so with that removed it had zero
  // real tags left (see create_plan_wizard_controller.dart).
  'Beach': ['Viewpoint'],
  'City': ['Landmark'],
  'Nature': ['Viewpoint', 'Zoo'],
  'Adventure': ['Zoo', 'Theme Park'],
  'Culture': ['Art & Culture', 'Historic Site', 'Museum'],
  'Relaxation': ['Viewpoint'],
  'Wildlife': ['Zoo'],
  'History': ['Historic Site'],
  'Art': ['Museum'],
  'Religion': ['Temple', 'Shrine', 'Religious Site'],
  'Markets': ['Market'],
};

const int kInterestAffinityBonus = 4;

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
