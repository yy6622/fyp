import 'package:flutter/material.dart';

import '../../controllers/detail_page_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
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
  // Real city name for the origin/destination (Duffel's `city_name`
  // off the place object — see DuffelFlightOffer) — null when this
  // page was opened without one (Saved/History has no city data to
  // pass), in which case the subtitle under the IATA code falls back
  // to the code itself rather than ever showing a fixed placeholder
  // city.
  final String? fromCity;
  final String toCode;
  final String? toCity;
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
  // Real exact timestamps for [depTime]/[arrTime] above, when this page was
  // opened on a live Duffel search result (see explore_page.dart's
  // _flightDetailFor, which has the real DateTime on hand) — carried
  // through to TripFlight.departureAtIso/arrivalAtIso on booking so
  // functions/logistics.js can enforce real flight-time constraints on the
  // AI itinerary/optimise features. Null when this page was opened from
  // Saved or History (no live search result on hand), in which case the
  // booked flight just has no exact timestamp, same as before this existed.
  final DateTime? departureAt;
  final DateTime? arrivalAt;
  // Real per-offer detail from Duffel (see DuffelFlightOffer) — null
  // whenever Duffel's response didn't have it (or this page was opened
  // from Saved/History, which has no live offer behind it). Each row/
  // section below is hidden rather than ever padded out with a fixed
  // placeholder value, same "don't fabricate" rule the hotel detail page
  // already follows for amenities.
  final String? aircraftName;
  final String? cabinClass;
  final String? originTerminal;
  final String? destinationTerminal;
  final int? checkedBagQuantity;
  final int? carryOnBagQuantity;
  final bool? changeAllowed;
  final String? changePenaltyAmount;
  final String? changePenaltyCurrency;
  final bool? refundAllowed;
  final String? refundPenaltyAmount;
  final String? refundPenaltyCurrency;

  const DetailPageFlight({
    super.key,
    this.airline = 'Air Asia',
    this.fromCode = 'KUL',
    this.fromCity,
    this.toCode = 'NRT',
    this.toCity,
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
    this.departureAt,
    this.arrivalAt,
    this.aircraftName,
    this.cabinClass,
    this.originTerminal,
    this.destinationTerminal,
    this.checkedBagQuantity,
    this.carryOnBagQuantity,
    this.changeAllowed,
    this.changePenaltyAmount,
    this.changePenaltyCurrency,
    this.refundAllowed,
    this.refundPenaltyAmount,
    this.refundPenaltyCurrency,
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
                                      Text(widget.fromCity ?? widget.fromCode, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
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
                                      Text(widget.toCity ?? widget.toCode, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                              ],
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
                            routeCities: '${widget.fromCity ?? widget.fromCode} → ${widget.toCity ?? widget.toCode}',
                            dateTime: '${widget.date} ${widget.depTime}',
                            arrivalTime: '${widget.date} ${widget.arrTime}',
                            // .toIso8601String() with no .toUtc() first, so
                            // this stays the plain destination wall-clock
                            // time (see TripFlight's doc comment) — blank
                            // when this page wasn't opened with a real
                            // DateTime (Saved/History, not a fresh search).
                            departureAtIso: widget.departureAt?.toIso8601String() ?? '',
                            arrivalAtIso: widget.arrivalAt?.toIso8601String() ?? '',
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
                            forMemberUids: confirmation.forMemberUids,
                          ),
                          actorUid: AuthService.instance.currentUser?.uid,
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

  /// "1 bag"/"2 bags", or '' (renders as "-" via [InfoField]'s orDash)
  /// when Duffel's offer didn't carry a baggage allowance for this fare.
  String _bagLabel(int? qty) => qty == null ? '' : (qty == 1 ? '1 bag' : '$qty bags');

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
                Expanded(child: InfoField(label: 'Aircraft', value: widget.aircraftName ?? '')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: InfoField(label: 'Departure Terminal', value: widget.originTerminal ?? '')),
                Expanded(child: InfoField(label: 'Arrival Terminal', value: widget.destinationTerminal ?? '')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: InfoField(label: 'Cabin', value: widget.cabinClass ?? '')),
                Expanded(child: InfoField(label: 'Checked Baggage', value: _bagLabel(widget.checkedBagQuantity))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: InfoField(label: 'Carry-on', value: _bagLabel(widget.carryOnBagQuantity))),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// Builds the one real sentence Duffel's conditions block supports for
  /// "change" or "refund" — `allowed == null` means Duffel itself didn't
  /// return fare-rule data for this offer, in which case there's nothing
  /// honest to say and the caller leaves the row out entirely, rather
  /// than guessing "allowed" or "not allowed".
  String? _conditionText({required bool? allowed, required String verb, required String? amount, required String? currency}) {
    if (allowed == null) return null;
    if (allowed == false) return 'Not $verb';
    final hasFee = amount != null && amount.isNotEmpty && double.tryParse(amount) != null && double.parse(amount) > 0;
    if (!hasFee) return '${verb[0].toUpperCase()}${verb.substring(1)}, no fee';
    return '${verb[0].toUpperCase()}${verb.substring(1)} — ${currency ?? ''} $amount fee applies';
  }

  List<Widget> _fareRulesContent() {
    final changeText = _conditionText(
      allowed: widget.changeAllowed,
      verb: 'changeable',
      amount: widget.changePenaltyAmount,
      currency: widget.changePenaltyCurrency,
    );
    final refundText = _conditionText(
      allowed: widget.refundAllowed,
      verb: 'refundable',
      amount: widget.refundPenaltyAmount,
      currency: widget.refundPenaltyCurrency,
    );
    final rows = [
      if (refundText != null) FareRuleRow(icon: Icons.event_available_outlined, text: refundText),
      if (changeText != null) FareRuleRow(icon: Icons.edit_calendar_outlined, text: changeText),
    ];
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
        child: rows.isEmpty
            ? const Text(
                "This fare's change/refund rules weren't provided by the airline — check with them before booking.",
                style: TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.4),
              )
            : Column(
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    rows[i],
                  ],
                ],
              ),
      ),
    ];
  }
}
