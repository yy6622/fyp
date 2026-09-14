import 'package:flutter/material.dart';

import '../../theme.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Flight detail
// ---------------------------------------------------------------------
class DetailPageFlight extends StatelessWidget {
  // Defaults match the Explore-flow Air Asia KUL→NRT mock so existing
  // callers (explore_page.dart) render exactly as before. History passes
  // the actual tapped booking's route/date/time/price through so the
  // detail page it opens on actually reflects what was tapped, instead of
  // always showing this same static flight regardless of which row you
  // tap from History.
  final String airline;
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final String flightNo;
  final String date;
  final String depTime;
  final String arrTime;
  final String duration;
  final String stops;
  final String price;
  final String priceSuffix;

  const DetailPageFlight({
    super.key,
    this.airline = 'Air Asia',
    this.fromCode = 'KUL',
    this.fromCity = 'Kuala Lumpur',
    this.toCode = 'NRT',
    this.toCity = 'Tokyo (Narita)',
    this.flightNo = 'AK71',
    this.date = '12 June 2026',
    this.depTime = '9:20',
    this.arrTime = '17:25',
    this.duration = '7h5m',
    this.stops = 'Non-stop',
    this.price = 'RM 899',
    this.priceSuffix = 'One Way',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            DetailHeader(title: airline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fromCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const SizedBox(height: 4),
                            Text(fromCity, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward, color: AppColors.navy),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(toCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const SizedBox(height: 4),
                            Text(toCity, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('$flightNo · $stops', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(depTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(duration, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            const SizedBox(height: 6),
                            const Divider(color: AppColors.textGrey, thickness: 1),
                            Text(stops, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(arrTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 16),
                  const Text('Flight Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.chipGrey,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: InfoField(label: 'Flight Number', value: flightNo)),
                            const Expanded(child: InfoField(label: 'Aircraft', value: 'Airbus A330-300')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: InfoField(label: 'Departure Terminal', value: 'Terminal 1 (KLIA)')),
                            Expanded(child: InfoField(label: 'Arrival Terminal', value: 'Terminal 2 (NRT)')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: InfoField(label: 'Cabin', value: 'Economy')),
                            Expanded(child: InfoField(label: 'Checked Baggage', value: '20kg')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: InfoField(label: 'Carry-on', value: '7kg')),
                            Expanded(child: InfoField(label: 'Seats Left', value: '12 seats')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 74,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        AmenityIcon(icon: Icons.wifi, label: 'Wi-Fi'),
                        AmenityIcon(icon: Icons.restaurant_outlined, label: 'Meal Included'),
                        AmenityIcon(icon: Icons.tv_outlined, label: 'Entertainment'),
                        AmenityIcon(icon: Icons.battery_charging_full, label: 'Power Outlet'),
                        AmenityIcon(icon: Icons.airline_seat_legroom_extra, label: 'Extra Legroom'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Fare Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: const Column(
                      children: [
                        FareRuleRow(icon: Icons.event_available_outlined, text: 'Free cancellation within 24 hours of booking'),
                        SizedBox(height: 12),
                        FareRuleRow(icon: Icons.edit_calendar_outlined, text: 'Date change allowed — RM 150 fee applies'),
                        SizedBox(height: 12),
                        FareRuleRow(icon: Icons.block_outlined, text: 'Non-refundable after departure'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BookingBar(
              price: price,
              priceSuffix: priceSuffix,
              buttonLabel: 'Select Flight',
              bookingType: 'flight',
              bookingTitle: '$fromCode → $toCode',
              bookingSubtitle: '$date $depTime',
            ),
          ],
        ),
      ),
    );
  }
}
