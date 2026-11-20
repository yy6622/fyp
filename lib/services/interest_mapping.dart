// These values must match the categories used by Admin > Add Attraction.
// Use actual catalogue tags rather than treating different interests as
// the same generic "Viewpoint" category.
const Map<String, List<String>> kInterestToAttractionCategoryTags = {
  'Beach': ['Beach'],
  'City': ['Landmark', 'Monument', 'Shopping Mall', 'Market'],
  'Nature': ['Nature Reserve', 'Park', 'Garden', 'Viewpoint'],
  'Adventure': ['Theme Park', 'Nature Reserve'],
  'Culture': ['Art & Culture', 'Historic Site', 'Museum', 'Monument'],
  'Relaxation': ['Beach', 'Garden', 'Park', 'Viewpoint'],
  'Wildlife': ['Zoo', 'Aquarium', 'Nature Reserve'],
  'History': ['Historic Site', 'Museum', 'Monument'],
  'Art': ['Art & Culture', 'Museum'],
  'Religion': ['Temple', 'Shrine', 'Religious Site'],
  'Markets': ['Market'],
};

const int kInterestAffinityBonus = 4;

String normalizedAttractionCategory(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Real attraction category tags preferred by the selected plan. Stored trip
/// interests are matched case-insensitively (including older plans).
Set<String> attractionCategoryTagsForInterests(Iterable<String> interests) {
  final wanted = <String>{};
  for (final interest in interests) {
    final normalizedInterest = normalizedAttractionCategory(interest);
    for (final entry in kInterestToAttractionCategoryTags.entries) {
      if (normalizedAttractionCategory(entry.key) != normalizedInterest) continue;
      for (final tag in entry.value) {
        wanted.add(normalizedAttractionCategory(tag));
      }
      break;
    }
  }
  return wanted;
}

Map<String, int> blendInterestsIntoAffinity(Map<String, int> affinity, List<String> interests) {
  if (interests.isEmpty) return affinity;
  final blended = Map<String, int>.from(affinity);
  for (final interest in interests) {
    final normalizedInterest = normalizedAttractionCategory(interest);
    for (final entry in kInterestToAttractionCategoryTags.entries) {
      if (normalizedAttractionCategory(entry.key) != normalizedInterest) continue;
      for (final tag in entry.value) {
        blended[tag] = (blended[tag] ?? 0) + kInterestAffinityBonus;
      }
      break;
    }
  }
  return blended;
}
