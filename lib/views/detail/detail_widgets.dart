import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/duffel_models.dart';
import '../../models/review_models.dart';
import '../../repositories/review_helpers.dart' show ReviewSubmitOutcome;
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import 'all_reviews_page.dart';
import 'booking_payment_page.dart';
import 'flight_passenger_details_page.dart';
import 'hotel_guest_details_page.dart';

class DetailHeader extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? logoUrl;
  final bool showHero;
  final IconData fallbackIcon;
  const DetailHeader({
    super.key,
    required this.title,
    this.imageUrl,
    this.logoUrl,
    this.showHero = true,
    this.fallbackIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        if (showHero) _buildHero(),
      ],
    );
  }

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
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallbackBox(),
        errorWidget: (_, __, ___) => _fallbackBox(),
      );
    }
    return _fallbackBox();
  }

  Widget _fallbackBox() => Container(
        height: 160,
        width: double.infinity,
        color: AppColors.chipGrey,
        alignment: Alignment.center,
        child: _fallbackIcon(fallbackIcon),
      );

  Widget _fallbackIcon(IconData icon) => Icon(icon, size: 44, color: AppColors.textGrey);
}

Widget tagChip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
  );
}

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
  final String bookingType;
  final String bookingTitle;
  final String bookingSubtitle;
  final String refId;
  final String tripId;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final List<DuffelOfferPassenger> offerPassengers;
  final double offerTotalAmount;
  final String offerTotalCurrency;
  final DateTime? departureAt;
  // Flight-only -- everything the booking summary needs to show a real
  // itinerary (route, times, duration, airline, cabin) before payment,
  // not just the thin "KUL -> TFU / 22 Nov 18:45" bookingTitle/Subtitle.
  final String? fromCode;
  final String? fromCity;
  final String? toCode;
  final String? toCity;
  final String? flightDate;
  final String? depTime;
  final String? arrTime;
  final String? duration;
  final String? stops;
  final String? airline;
  final String? airlineLogoUrl;
  final String? cabinClass;
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
    this.checkIn,
    this.checkOut,
    this.offerPassengers = const [],
    this.offerTotalAmount = 0,
    this.offerTotalCurrency = '',
    this.departureAt,
    this.fromCode,
    this.fromCity,
    this.toCode,
    this.toCity,
    this.flightDate,
    this.depTime,
    this.arrTime,
    this.duration,
    this.stops,
    this.airline,
    this.airlineLogoUrl,
    this.cabinClass,
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
                        offerPassengers: offerPassengers,
                        offerTotalAmount: offerTotalAmount,
                        offerTotalCurrency: offerTotalCurrency,
                        departureAt: departureAt,
                        fromCode: fromCode,
                        fromCity: fromCity,
                        toCode: toCode,
                        toCity: toCity,
                        flightDate: flightDate,
                        depTime: depTime,
                        arrTime: arrTime,
                        duration: duration,
                        stops: stops,
                        airline: airline,
                        airlineLogoUrl: airlineLogoUrl,
                        cabinClass: cabinClass,
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
                        initialCheckIn: checkIn,
                        initialCheckOut: checkOut,
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

class SaveHeartBox extends StatelessWidget {
  final bool saved;
  final VoidCallback? onTap;
  const SaveHeartBox({super.key, required this.saved, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.chipGrey,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: saved ? Colors.redAccent : AppColors.textGrey,
        ),
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

class ReviewData {
  final String authorId;
  final String name;
  final String flag;
  final String country;
  final int rating;
  final String comment;
  final String timeAgo;
  final bool autoFlagged;
  const ReviewData({
    this.authorId = '',
    required this.name,
    this.flag = '',
    this.country = '',
    required this.rating,
    required this.comment,
    this.timeAgo = '',
    this.autoFlagged = false,
  });
}

ReviewData reviewDataFromPlace(PlaceReview r) => ReviewData(
      authorId: r.authorId,
      name: r.authorName,
      rating: r.rating,
      comment: r.comment,
      timeAgo: r.createdAt == null ? 'Just now' : formatTimeAgo(r.createdAt!),
      autoFlagged: r.autoFlagged,
    );

class ReviewCard extends StatelessWidget {
  final ReviewData data;
  const ReviewCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final initial = data.name.trim().isEmpty ? '?' : data.name.trim()[0].toUpperCase();
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
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(colorValueForName(data.name)),
                child: Text(initial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
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
          if (data.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(data.comment, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
          if (data.autoFlagged) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.hourglass_top, size: 12, color: AppColors.orange),
                SizedBox(width: 5),
                Text('Pending review — only visible to you until an admin checks it',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.orange)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showWriteReviewDialog(
  BuildContext context, {
  required String title,
  required Future<ReviewSubmitOutcome> Function({required String authorId, required String authorName, required int rating, required String comment}) onSubmit,
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
      niceDialogField(commentController, 'Share your experience (optional)...', icon: Icons.edit_outlined, maxLines: 4),
    ],
  );
  if (result != true) return;
  final comment = commentController.text.trim();
  final profile = await UserRepository.instance.fetchProfile(uid);
  final name = (profile != null && profile.name.isNotEmpty) ? profile.name : 'Traveller';
  final outcome = await onSubmit(authorId: uid, authorName: name, rating: rating, comment: comment);
  if (!context.mounted) return;
  if (outcome == ReviewSubmitOutcome.pendingModeration) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your review was submitted and is pending moderation review.')),
    );
  } else if (outcome == ReviewSubmitOutcome.alreadyReviewed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You've already reviewed this — each traveller can only leave one review, and reviews can't be edited once submitted.")),
    );
  }
}

class ReviewsSection extends StatelessWidget {
  final String title;
  final String ratingSummary;
  final Stream<List<ReviewData>> reviewsStream;
  final Future<ReviewSubmitOutcome> Function({required String authorId, required String authorName, required int rating, required String comment}) onSubmitReview;
  final bool allowWriting;
  final String myUid;
  const ReviewsSection({
    super.key,
    required this.title,
    required this.ratingSummary,
    required this.reviewsStream,
    required this.onSubmitReview,
    this.allowWriting = true,
    this.myUid = '',
  });

  void _onWriteReviewTap(BuildContext context, bool alreadyReviewed) {
    if (alreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've already reviewed this — each traveller can only leave one review.")),
      );
      return;
    }
    showWriteReviewDialog(context, title: 'Rate & Review', onSubmit: onSubmitReview);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewData>>(
      stream: reviewsStream,
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const [];
        final alreadyReviewed = myUid.isNotEmpty && reviews.any((r) => r.authorId == myUid);
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
                        onTap: () => _onWriteReviewTap(context, alreadyReviewed),
                        child: Text(
                          alreadyReviewed ? 'You reviewed this' : 'Write a Review',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: alreadyReviewed ? AppColors.textGrey : AppColors.primary,
                          ),
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
