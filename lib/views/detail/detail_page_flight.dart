import 'package:flutter/material.dart';

import '../../controllers/detail_page_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../theme.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Flight detail
// ---------------------------------------------------------------------
class DetailPageFlight extends StatefulWidget {
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
  // Duffel's real carrier logo (SVG) for this flight's airline — there's
  // no per-flight photo concept, so this is what the header shows instead
  // of a photo. Null/empty falls back to a neutral flight icon.
  final String? airlineLogoUrl;
  // The trip this flight should be added to once payment succeeds (see
  // BookingBar's onPaid) — blank when this page was opened with no trip
  // context (e.g. no trip selected on Explore yet), in which case paying
  // just records the booking in History same as before, with nothing
  // auto-added to a plan.
  final String tripId;

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
    this.airlineLogoUrl,
    this.tripId = '',
  });

  @override
  State<DetailPageFlight> createState() => _DetailPageFlightState();
}

class _DetailPageFlightState extends State<DetailPageFlight> {
  final DetailPageFlightController controller = DetailPageFlightController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DetailHeader(title: widget.airline, logoUrl: widget.airlineLogoUrl),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.fromCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                      const SizedBox(height: 4),
                                      Text(widget.fromCity, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
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
                                      Text(widget.toCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                      const SizedBox(height: 4),
                                      Text(widget.toCity, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text('${widget.flightNo} · ${widget.stops}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.depTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                                      const SizedBox(height: 4),
                                      Text(widget.date, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(widget.duration, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                      const SizedBox(height: 6),
                                      const Divider(color: AppColors.textGrey, thickness: 1),
                                      Text(widget.stops, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(widget.arrTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                                      const SizedBox(height: 4),
                                      Text(widget.date, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Same Details/X two-tab pattern DetailPageHotel
                            // uses — flights have no reviewable catalog
                            // entity (see DetailPageFlightController's doc
                            // comment), so the second tab is Fare Rules
                            // instead of Review.
                            Row(
                              children: [
                                Expanded(child: _tabButton('Details', !controller.showFareRules)),
                                Expanded(child: _tabButton('Fare Rules', controller.showFareRules)),
                              ],
                            ),
                            const Divider(height: 1, color: Color(0xFFECECEC)),
                            const SizedBox(height: 16),
                            if (!controller.showFareRules) ..._detailsContent() else ..._fareRulesContent(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              BookingBar(
                price: widget.price,
                priceSuffix: widget.priceSuffix,
                buttonLabel: 'Select Flight',
                bookingType: 'flight',
                bookingTitle: '${widget.fromCode} → ${widget.toCode}',
                bookingSubtitle: '${widget.date} ${widget.depTime}',
                tripId: widget.tripId,
                onPaid: widget.tripId.isEmpty
                    ? null
                    : (confirmation) => TripRepository.instance.addFlight(
                          widget.tripId,
                          TripFlight(
                            id: '${DateTime.now().microsecondsSinceEpoch}',
                            airline: widget.airline,
                            flightNumber: widget.flightNo,
                            routeCode: '${widget.fromCode} → ${widget.toCode}',
                            routeCities: '${widget.fromCity} → ${widget.toCity}',
                            dateTime: '${widget.date} ${widget.depTime}',
                            terminal: '',
                            // The real Stripe PaymentIntent id this charge
                            // went through under — a genuine reference tied
                            // to an actual transaction, not a made-up PNR.
                            bookingRef: confirmation.paymentRef,
                            status: 'Confirmed',
                            passengers: confirmation.passengerNames,
                            passengerDetails: confirmation.passengerDetails,
                            contactEmail: confirmation.contactEmail,
                            contactPhone: confirmation.contactPhone,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected) {
    return GestureDetector(
      onTap: () => controller.setShowFareRules(label == 'Fare Rules'),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textGrey,
          ),
        ),
      ),
    );
  }

  List<Widget> _detailsContent() {
    return [
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
                Expanded(child: InfoField(label: 'Flight Number', value: widget.flightNo)),
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
    ];
  }

  List<Widget> _fareRulesContent() {
    return [
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
    ];
  }
}
