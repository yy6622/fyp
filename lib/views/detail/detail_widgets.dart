import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/review_models.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import '../shared/translated_text.dart';
import 'all_reviews_page.dart';
import 'booking_payment_page.dart';
import 'flight_passenger_details_page.dart';
import 'hotel_guest_details_page.dart';

// ---------------------------------------------------------------------
// Shared bits used across the flight/hotel/plan detail pages
// ---------------------------------------------------------------------
class DetailHeader extends StatelessWidget {
  final String title;
  /// The real photo for whatever this detail page is showing (a hotel,
  /// restaurant, attraction or manually-added place) — null/empty when
  /// the source has none, in which case [_fallbackBox] shows instead of
  /// guessing at a stock photo.
  final String? imageUrl;
  /// A flight has no per-offer photo — Duffel only gives the airline's own
  /// logo (SVG), so flight detail pages pass this instead of [imageUrl].
  /// Takes priority over [imageUrl] when both are somehow set.
  final String? logoUrl;
  /// True for a real-world place name (attraction/hotel/restaurant) that
  /// should show translated into the person's chosen language (see
  /// TranslatedText) — false (default) for a flight's airline name or
  /// anything else [title] might hold that isn't a place name worth
  /// running through a translator.
  final bool translate;
  const DetailHeader({super.key, required this.title, this.imageUrl, this.logoUrl, this.translate = false});

  @override
  Widget build(BuildContext context) {
    // A plain white app bar (back button + centered title + bottom
    // border) sitting above the hero photo — matching the flight/hotel
    // detail designs — rather than the title being overlaid on the image.
    return Column(
      children: [
        Container(
          height: 52,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFECECEC), width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: translate
                    ? TranslatedText(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                      )
                    : Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        _buildHero(),
      ],
    );
  }

  // Used to previously be a fixed `adventure_bg.jpg` stock photo on every
  // single detail page regardless of what was being viewed (a hotel page
  // showed the same picture as a flight page) — now the real photo/logo
  // for the thing actually being shown, falling back to a neutral icon
  // box (never the old stock photo) when there's no real image to show.
  Widget _buildHero() {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        color: AppColors.chipGrey,
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SvgPicture.network(
            logoUrl!,
            placeholderBuilder: (_) => _fallbackIcon(Icons.flight),
            errorBuilder: (_, __, ___) => _fallbackIcon(Icons.flight),
          ),
        ),
      );
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : _fallbackBox(),
        errorBuilder: (_, __, ___) => _fallbackBox(),
      );
    }
    return _fallbackBox();
  }

  Widget _fallbackBox() => Container(
        height: 160,
        width: double.infinity,
        color: AppColors.chipGrey,
        alignment: Alignment.center,
        child: _fallbackIcon(Icons.image_outlined),
      );

  Widget _fallbackIcon(IconData icon) => Icon(icon, size: 44, color: AppColors.textGrey);
}

/// A small standalone pill for one tag/category label — used wherever a
/// place has more than one tag (cuisine, category) so each shows as its
/// own chip instead of being joined into one string with a "•" separator.
Widget tagChip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
  );
}

/// A single bullet-style rule row (icon + text), used by the flight
/// detail page's "Fare Rules" section.
class FareRuleRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const FareRuleRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3)),
        ),
      ],
    );
  }
}

/// A real Firestore/API field (a flight/hotel/attraction/place's actual
/// data) that came back empty shows as "-" rather than a blank space —
/// blank reads as "the page is broken", "-" reads as "this place just
/// doesn't have that info". Doesn't apply to a value that's already a
/// deliberate, more specific fallback string (e.g. "Not specified",
/// "Flexible") — those already say something more useful than "-" would.
String orDash(String value) => value.trim().isEmpty ? '-' : value;

class InfoField extends StatelessWidget {
  final String label;
  final String value;
  const InfoField({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        Text(orDash(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
      ],
    );
  }
}

class BookingBar extends StatelessWidget {
  final String price;
  final String priceSuffix;
  final String buttonLabel;
  // Which History tab this purchase should show up under, and what its row
  // should read there — e.g. bookingType 'flight', bookingTitle 'KUL →
  // NRT', bookingSubtitle '12 June 2026 9:20'. Confirming the booking below
  // writes a real `users/{uid}/bookings` doc so it's not just a dialog —
  // History reads from the same collection (see [BookingRepository]).
  final String bookingType;
  final String bookingTitle;
  final String bookingSubtitle;
  // Catalog doc id this booking refers to (e.g. a `catalog_hotels` doc id)
  // so History Detail can later show real reviews for the actual place —
  // blank when there's no such catalog target.
  final String refId;
  // The trip this booking should be auto-added to once payment succeeds
  // (blank when there's no trip context) and the callback that actually
  // does that add — built by the caller (DetailPageFlight/DetailPageHotel)
  // since only they have the full flight/hotel data a trip record needs.
  final String tripId;
  final Future<void> Function(BookingConfirmation confirmation)? onPaid;
  const BookingBar({
    super.key,
    required this.price,
    required this.priceSuffix,
    required this.buttonLabel,
    required this.bookingType,
    required this.bookingTitle,
    required this.bookingSubtitle,
    this.refId = '',
    this.tripId = '',
    this.onPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text(priceSuffix, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              // Was an instant "confirm and write the booking right here,
              // no payment step at all" tap — now goes through a real
              // multi-step checkout (Passenger/Guest Details -> Payment),
              // the same shape Insurance's own purchase flow uses
              // (TravellerDetailsPage -> PaymentMethodPage), instead of
              // skipping straight to "booked" with just a name.
              final unitPrice = double.tryParse(price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
              final currencyLabel = price.replaceAll(RegExp(r'[0-9.,\s]'), '');
              final resolvedCurrency = currencyLabel.isEmpty ? price : currencyLabel;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => bookingType == 'flight'
                    ? FlightPassengerDetailsPage(
                        itemTitle: bookingTitle,
                        itemSubtitle: bookingSubtitle,
                        unitPrice: unitPrice,
                        currencyLabel: resolvedCurrency,
                        unitSuffix: priceSuffix,
                        bookingTitle: bookingTitle,
                        bookingSubtitle: bookingSubtitle,
                        refId: refId,
                        tripId: tripId,
                        onPaid: onPaid,
                      )
                    : HotelGuestDetailsPage(
                        itemTitle: bookingTitle,
                        itemSubtitle: bookingSubtitle,
                        unitPrice: unitPrice,
                        currencyLabel: resolvedCurrency,
                        unitSuffix: priceSuffix,
                        bookingTitle: bookingTitle,
                        bookingSubtitle: bookingSubtitle,
                        refId: refId,
                        tripId: tripId,
                        onPaid: onPaid,
                      ),
              ));
            },
            child: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class AmenityIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const AmenityIcon({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 8.5, color: AppColors.textGrey, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shape [ReviewCard] renders — always built from live Firestore data
/// via [reviewDataFromPlace] (see [ReviewsSection]). [flag]/[country] are
/// optional and blank for a real user review (we don't know a reviewer's
/// country); [timeAgo] fills the same subtitle line instead when they're
/// blank.
class ReviewData {
  final String name;
  final String flag;
  final String country;
  final int rating;
  final String comment;
  final String timeAgo;
  const ReviewData({
    required this.name,
    this.flag = '',
    this.country = '',
    required this.rating,
    required this.comment,
    this.timeAgo = '',
  });
}

/// Converts one real Firestore-backed [PlaceReview] into the [ReviewData]
/// shape [ReviewCard] already knows how to render.
ReviewData reviewDataFromPlace(PlaceReview r) => ReviewData(
      name: r.authorName,
      rating: r.rating,
      comment: r.comment,
      timeAgo: r.createdAt == null ? 'Just now' : formatTimeAgo(r.createdAt!),
    );

class ReviewCard extends StatelessWidget {
  final ReviewData data;
  const ReviewCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                    if (data.flag.isNotEmpty || data.country.isNotEmpty)
                      Text('${data.flag} ${data.country}'.trim(), style: const TextStyle(fontSize: 10, color: AppColors.textGrey))
                    else if (data.timeAgo.isNotEmpty)
                      Text(data.timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(Icons.star, size: 13, color: i < data.rating ? AppColors.orange : const Color(0xFFDDDDDD)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.comment, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }
}

/// Opens the shared "write a review" popup (star picker + comment, in the
/// same rounded-card style as [showNiceFormDialog] everywhere else) and,
/// if the person actually submits one, resolves their display name and
/// calls [onSubmit] with the chosen rating/comment. Used by every real
/// "Reviews" section (see [ReviewsSection]) so Hotel/Restaurant/Attraction/
/// Community post all write reviews the same way.
Future<void> showWriteReviewDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function({required String authorId, required String authorName, required int rating, required String comment}) onSubmit,
}) async {
  final uid = AuthService.instance.currentUser?.uid;
  if (uid == null) return;
  int rating = 5;
  final commentController = TextEditingController();
  final result = await showNiceFormDialog(
    context: context,
    title: title,
    headerIcon: Icons.rate_review_outlined,
    confirmLabel: 'Submit',
    fieldsBuilder: (ctx, setState) => [
      niceStarPicker(rating: rating, onChanged: (v) => setState(() => rating = v)),
      niceDialogField(commentController, 'Share your experience...', icon: Icons.edit_outlined, maxLines: 4),
    ],
  );
  if (result != true) return;
  final comment = commentController.text.trim();
  if (comment.isEmpty) return;
  final profile = await UserRepository.instance.fetchProfile(uid);
  final name = (profile != null && profile.name.isNotEmpty) ? profile.name : 'Traveller';
  await onSubmit(authorId: uid, authorName: name, rating: rating, comment: comment);
}

/// The shared "Reviews" section used by every real detail page (Hotel,
/// Restaurant, Attraction, Community post) — a live-streamed top-3
/// preview, "Write a Review", and (once there are more than 3) "View All".
/// Everything here is real: [reviewsStream] comes straight from Firestore,
/// nothing is canned/sample content.
class ReviewsSection extends StatelessWidget {
  final String title;
  final String ratingSummary;
  final Stream<List<ReviewData>> reviewsStream;
  final Future<void> Function({required String authorId, required String authorName, required int rating, required String comment}) onSubmitReview;
  // Hotel reviews can only be written from History (after a real stay),
  // not from the Hotel detail page itself — a hotel stay is a real paid
  // transaction, so its reviews should read like genuine guest feedback,
  // not a comment section anyone passing through Explore can post to.
  // Restaurant/Attraction reviews (and a Community post's comments,
  // which also use this same widget) stay open to everyone, same as
  // before. [allowWriting] controls whether "Write a Review" shows at
  // all; DetailPageHotel passes false, HistoryHotelDetailPage (the only
  // legitimate channel to write one) leaves it at the default true.
  final bool allowWriting;
  const ReviewsSection({
    super.key,
    required this.title,
    required this.ratingSummary,
    required this.reviewsStream,
    required this.onSubmitReview,
    this.allowWriting = true,
  });

  void _onWriteReviewTap(BuildContext context) {
    showWriteReviewDialog(context, title: 'Rate & Review', onSubmit: onSubmitReview);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewData>>(
      stream: reviewsStream,
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                Row(
                  children: [
                    if (allowWriting)
                      GestureDetector(
                        onTap: () => _onWriteReviewTap(context),
                        child: const Text(
                          'Write a Review',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    if (reviews.length > 3) ...[
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AllReviewsPage(title: title, ratingSummary: ratingSummary, reviews: reviews),
                        )),
                        child: const Text('View All', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blue)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              const Text('No reviews yet — be the first to share your experience!', style: TextStyle(fontSize: 12, color: AppColors.textGrey))
            else
              ...reviews.take(3).expand((r) => [ReviewCard(data: r), const SizedBox(height: 12)]),
          ],
        );
      },
    );
  }
}
