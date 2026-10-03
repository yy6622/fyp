import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------
// Plan_Hotel_Detail — a hotel stay already on a trip's itinerary
// (trip.hotelStays). Previously tapping one of these reused
// DetailPageHotel, which is the *buy a hotel* page (its own "Select
// Hotel" purchase bar) — confusing for something already booked, and
// wrong since it has nothing to do with this stay's real check-in/
// check-out/guest data. This is the read-only counterpart to
// PlanFlightDetailPage, for the same reason.
// ---------------------------------------------------------------------
class PlanHotelDetailPage extends StatelessWidget {
  final String name;
  final String location;
  final String checkIn;
  final String checkOut;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestIdNumber;
  final String specialRequests;

  const PlanHotelDetailPage({
    super.key,
    required this.name,
    required this.location,
    this.checkIn = '',
    this.checkOut = '',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.guestIdNumber = '',
    this.specialRequests = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: const Text('Hotel Stay', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFE4E4E4),
                  child: const Text('HOTEL STAY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                ),
                _field('Hotel Name', name.isEmpty ? 'Not specified' : name),
                _field('Location', location.isEmpty ? 'Not specified' : location),
                _field('Check-in', checkIn.isEmpty ? 'Not specified' : checkIn),
                _field('Check-out', checkOut.isEmpty ? 'Not specified' : checkOut),
                _field('Guest Name', guestName.isEmpty ? 'Not available' : guestName),
                _field('Guest Email', guestEmail.isEmpty ? 'Not available' : guestEmail),
                _field('Guest Phone', guestPhone.isEmpty ? 'Not available' : guestPhone),
                _field('Passport / ID Number', guestIdNumber.isEmpty ? 'Not available' : guestIdNumber),
                _field('Special Requests', specialRequests.isEmpty ? 'None' : specialRequests, last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE4E4E4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
