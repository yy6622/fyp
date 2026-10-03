import 'package:flutter/material.dart';

import '../../repositories/catalog_repository.dart';
import '../../theme.dart';
import '../shared/contact_launcher.dart';
import '../shared/translated_text.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Restaurant detail
// ---------------------------------------------------------------------
// Like attractions, restaurants don't have a purchase flow — there's no
// table-reservation system in this app — so the bottom bar is a save
// toggle instead of [BookingBar], same convention as
// [DetailPageAttraction]. Saving is scoped to whichever trip the
// restaurant was opened from (see CatalogRepository's class doc); when
// there's no trip context (onToggleSave is null) the button is disabled.
class DetailPageRestaurant extends StatefulWidget {
  final CatalogRestaurant restaurant;
  final bool saved;
  final VoidCallback? onToggleSave;

  const DetailPageRestaurant({
    super.key,
    required this.restaurant,
    this.saved = false,
    this.onToggleSave,
  });

  @override
  State<DetailPageRestaurant> createState() => _DetailPageRestaurantState();
}

class _DetailPageRestaurantState extends State<DetailPageRestaurant> {
  late bool _saved = widget.saved;

  void _toggle() {
    setState(() => _saved = !_saved);
    widget.onToggleSave?.call();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DetailHeader(title: r.name, imageUrl: r.image, translate: true),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        // Same fix as DetailPageAttraction: without this,
                        // Column centers every child that doesn't already
                        // fill the width (title, rating, "About"), which is
                        // why this page used to look inconsistent with
                        // Flight/Hotel's left-aligned layout.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          const SizedBox(height: 8),
                          // Star sits before the rating number, matching how every
                          // other detail page (Hotel, and now Attraction) shows a
                          // rating — not floated off to the side of the title.
                          Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: AppColors.orange),
                              const SizedBox(width: 4),
                              Text('${r.rating} (${r.reviews} reviews)', style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Each cuisine tag is its own chip — not one label joined
                          // with a "•" dot — so they read as separate, scannable
                          // tags (e.g. "Japanese" and "Ramen" side by side).
                          Wrap(spacing: 6, runSpacing: 6, children: r.cuisineTags.map(tagChip).toList()),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(orDash(r.address.isNotEmpty ? r.address : r.location), style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFECECEC)),
                          const SizedBox(height: 16),
                          const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          const SizedBox(height: 10),
                          Text(
                            // See DetailPageAttraction's About text for why
                            // this prefers a real description over the
                            // generic cuisine sentence when one exists.
                            r.description.isNotEmpty
                                ? r.description
                                : 'A popular ${r.cuisineLabel.toLowerCase()} spot on this trip. Save it to your plan and check '
                                    'opening hours and directions closer to your visit date.',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Expanded(child: InfoField(label: 'Price Range', value: r.priceRange)),
                                Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
                                const SizedBox(width: 16),
                                Expanded(child: InfoField(label: 'Opening Hours', value: r.openingHours)),
                              ],
                            ),
                          ),
                          if (r.phone.isNotEmpty || r.website.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text('Contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const SizedBox(height: 12),
                            if (r.phone.isNotEmpty) _contactRow(Icons.phone_outlined, r.phone, () => confirmAndLaunch(context, ContactAction.call, r.phone)),
                            if (r.phone.isNotEmpty && r.website.isNotEmpty) const SizedBox(height: 10),
                            if (r.website.isNotEmpty) _contactRow(Icons.language_outlined, r.website, () => confirmAndLaunch(context, ContactAction.website, r.website)),
                          ],
                          const SizedBox(height: 24),
                          ReviewsSection(
                            title: r.name,
                            ratingSummary: '${r.rating} (${r.reviews} reviews)',
                            reviewsStream: CatalogRepository.instance.watchRestaurantReviews(r.id).map((list) => list.map(reviewDataFromPlace).toList()),
                            onSubmitReview: ({required authorId, required authorName, required rating, required comment}) =>
                                CatalogRepository.instance.addRestaurantReview(
                              r.id,
                              authorId: authorId,
                              authorName: authorName,
                              rating: rating,
                              comment: comment,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orDash(r.priceRange), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Text('per pax', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved ? Colors.white : AppColors.primary,
                      side: _saved ? const BorderSide(color: AppColors.primary) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onToggleSave == null ? null : _toggle,
                    icon: Icon(_saved ? Icons.favorite : Icons.favorite_border, size: 18, color: _saved ? AppColors.primary : Colors.white),
                    label: Text(
                      _saved ? 'Saved' : 'Save',
                      style: TextStyle(color: _saved ? AppColors.primary : Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.primary, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}
