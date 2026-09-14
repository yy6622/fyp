import 'package:flutter/material.dart';

import '../../repositories/booking_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Shared bits used across the flight/hotel/plan detail pages
// ---------------------------------------------------------------------
class DetailHeader extends StatelessWidget {
  final String title;
  const DetailHeader({super.key, required this.title});

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
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        AppImage('assets/images/adventure_bg.jpg', height: 160, width: double.infinity, fit: BoxFit.cover),
      ],
    );
  }
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
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
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
  const BookingBar({
    super.key,
    required this.price,
    required this.priceSuffix,
    required this.buttonLabel,
    required this.bookingType,
    required this.bookingTitle,
    required this.bookingSubtitle,
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
              final uid = AuthService.instance.currentUser?.uid;
              if (uid != null) {
                BookingRepository.instance.addBooking(
                  uid: uid,
                  type: bookingType,
                  title: bookingTitle,
                  subtitle: bookingSubtitle,
                  trailing: '$price ($priceSuffix)',
                );
              }
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  title: Text('$buttonLabel confirmed', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                  content: Text('$price ($priceSuffix) has been added to your trip.',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
                  actions: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).maybePop();
                        },
                        child: const Text('Done', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
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

/// One canned review — there's no real review system in this app (no
/// Firestore collection backing it), so this is shared static content used
/// everywhere a "Reviews" section appears, instead of every page hardcoding
/// its own copy of the exact same single review.
class ReviewData {
  final String name;
  final String flag;
  final String country;
  final int rating;
  final String comment;
  const ReviewData({
    required this.name,
    required this.flag,
    required this.country,
    required this.rating,
    required this.comment,
  });
}

const List<ReviewData> kSampleReviews = [
  ReviewData(
    name: 'Vivi',
    flag: '🇲🇾',
    country: 'Malaysia',
    rating: 5,
    comment: 'The room was comfortable, clean, and spacious, and the air conditioning was cold enough.',
  ),
  ReviewData(
    name: 'Daniel Tan',
    flag: '🇸🇬',
    country: 'Singapore',
    rating: 4,
    comment: 'Great location and friendly staff. Would definitely come back on my next trip.',
  ),
  ReviewData(
    name: 'Aiko',
    flag: '🇯🇵',
    country: 'Japan',
    rating: 5,
    comment: 'Exceeded expectations — everything was exactly as described and check-in was smooth.',
  ),
  ReviewData(
    name: 'Marcus Lee',
    flag: '🇦🇺',
    country: 'Australia',
    rating: 4,
    comment: 'Solid experience overall, just a little noisy at night from the street outside.',
  ),
  ReviewData(
    name: 'Hana Kim',
    flag: '🇰🇷',
    country: 'South Korea',
    rating: 5,
    comment: 'Everything was spotless and the staff went out of their way to help us.',
  ),
  ReviewData(
    name: 'Farah',
    flag: '🇮🇩',
    country: 'Indonesia',
    rating: 4,
    comment: 'Really enjoyable experience — will recommend it to friends travelling this way.',
  ),
  ReviewData(
    name: 'Wei Jie',
    flag: '🇲🇾',
    country: 'Malaysia',
    rating: 5,
    comment: 'Worth every penny — will definitely book again on our next visit.',
  ),
  ReviewData(
    name: 'Noura',
    flag: '🇦🇪',
    country: 'UAE',
    rating: 4,
    comment: 'Nice experience overall, staff were attentive and quick to respond.',
  ),
];

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
                    Text('${data.flag} ${data.country}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
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
