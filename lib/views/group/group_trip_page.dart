import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../data/airlines.dart';
import '../../data/countries.dart';
import '../../data/country_gateways.dart';
import '../../data/malaysia_airports.dart';
import '../../models/day_plan_models.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../expenses/add_expense_choice_page.dart';
import '../expenses/expenses_tab.dart';
import '../insurance/insurance_list_page.dart';
import '../profile/history_detail_pages.dart';
import '../shared/nice_dialog.dart';
import '../shared/nice_pickers.dart';
import '../vote/create_vote_page.dart';
import '../vote/vote_tab.dart';
import 'group_info_page.dart';
import 'plan_flight_detail_page.dart';
import 'plan_hotel_detail_page.dart';

/// Airport/city choices offered by the "Add Flight" dialog's From/To
/// fields (see [_GroupTripPageState._addFlightDialog]) — typing a bare
/// 3-letter IATA code from memory isn't something most people can do, so
/// these fields now search real airport/city names (like the Airline
/// field already does for airlines) and the code is pulled out of
/// whichever suggestion gets picked. Built from the same two lists the
/// rest of the app already uses for flight search
/// ([kMalaysiaAirports] for a domestic "From", [kCountryGateways] for an
/// international "To"), so there's no separate/duplicate airport data.
final List<String> _flightLocationOptions = [
  for (final a in kMalaysiaAirports) '${a.city} – ${a.name} (${a.iataCode})',
  for (final g in kCountryGateways.entries) '${g.value.hotelPlaceQuery} (${g.value.flightIataCode})',
];

/// Pulls the trailing "(CODE)" back out of a picked [_flightLocationOptions]
/// suggestion. Falls back to just upper-casing whatever was typed, so
/// someone who still prefers to type a raw code directly (e.g. an
/// airport not in either list) isn't blocked.
String _extractAirportCode(String text) {
  final match = RegExp(r'\(([A-Za-z]{2,4})\)\s*$').firstMatch(text.trim());
  return (match?.group(1) ?? text.trim()).toUpperCase();
}

// ---------------------------------------------------------------------
// Group trip screen: Plan / Chat / Expenses / Vote tabs
// ---------------------------------------------------------------------
class GroupTripPage extends StatefulWidget {
  static const routeName = '/groupTrip';

  final String tripId;
  final GroupTab initialTab;
  const GroupTripPage({super.key, required this.tripId, this.initialTab = GroupTab.plan});

  @override
  State<GroupTripPage> createState() => _GroupTripPageState();
}

class _GroupTripPageState extends State<GroupTripPage> {
  late final GroupTripController controller = GroupTripController(tripId: widget.tripId, initialTab: widget.initialTab);

  // Toggled by the pencil icon next to the Day header — while on, every
  // activity card shows a delete button so activities can actually be
  // removed (there was previously no way to undo "Add Activity" at all).
  bool _dayEditMode = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
        }
        final trip = controller.trip;
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white, iconTheme: const IconThemeData(color: AppColors.navy)),
            body: const Center(child: Text('This trip no longer exists', style: TextStyle(color: AppColors.textGrey))),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.navy),
            titleSpacing: 0,
            title: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoPage(tripId: widget.tripId))),
              child: Row(
                children: [
                  const CircleAvatar(radius: 18, backgroundColor: Color(0xFFD9D9D9)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.name, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${trip.memberIds.length} members', style: const TextStyle(color: AppColors.textGrey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.navy),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoPage(tripId: widget.tripId))),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Row(
                children: [
                  _tabButton('Plan', Icons.sync_alt, GroupTab.plan),
                  _tabButton('Chat', Icons.chat_bubble_outline, GroupTab.chat),
                  _tabButton('Expenses', Icons.account_balance_wallet_outlined, GroupTab.expenses),
                  _tabButton('Vote', Icons.how_to_vote_outlined, GroupTab.vote),
                ],
              ),
            ),
          ),
          body: _buildBody(trip),
          floatingActionButton: controller.tab == GroupTab.expenses
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddExpenseChoicePage(tripId: widget.tripId)),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : controller.tab == GroupTab.vote
                  ? FloatingActionButton(
                      backgroundColor: AppColors.primary,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreateVotePage(tripId: widget.tripId)),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    )
                  : null,
        );
      },
    );
  }

  // Matches the Figma tab bar exactly (pulled via get_design_context on
  // node 57:256 "PlanDetail"): each tab is a white pill whose TOP corners
  // are square and BOTTOM corners are rounded (10px) — so its 2px bottom
  // border traces a little upward curve at each end instead of a flat
  // line. Only the selected tab's bottom border is navy; the other 3 have
  // a (invisible) white bottom border of the same width, so the curved
  // shape is there for all 4 but only the selected one's curve is visible.
  Widget _tabButton(String label, IconData icon, GroupTab tab) {
    final selected = controller.tab == tab;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => controller.setTab(tab),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.white, width: 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: selected ? AppColors.primary : AppColors.textGrey),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Trip trip) {
    switch (controller.tab) {
      case GroupTab.plan:
        return _buildPlanTab(trip);
      case GroupTab.chat:
        return _buildChatTab();
      case GroupTab.expenses:
        return ExpensesTab(tripId: widget.tripId);
      case GroupTab.vote:
        return VoteTab(tripId: widget.tripId);
    }
  }

  // ================= PLAN TAB =================
  Widget _buildPlanTab(Trip trip) {
    return Column(
      children: [
        Expanded(
          child: controller.planIndex == -1
              ? _overviewContent(trip)
              : _dayContent(trip, controller.days[controller.planIndex]),
        ),
        _planPager(),
      ],
    );
  }

  Widget _overviewContent(Trip trip) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 12),
        _overviewDateRow(trip),
        const SizedBox(height: 10),
        _overviewRow(Icons.place_outlined, trip.destination.isEmpty ? 'No destination set' : trip.destination, null,
            onTap: () => _editDestination(trip)),
        const SizedBox(height: 10),
        _overviewRow(Icons.savings_outlined, 'RM ${trip.budgetPerPerson.toStringAsFixed(0)} per person',
            trip.interests.isEmpty ? null : trip.interests.join(' · '), onTap: () => _editBudget(trip)),
        const SizedBox(height: 10),
        if (trip.flights.isEmpty)
          _addRow(Icons.flight_takeoff, 'Add a flight', onTap: _addFlightOrSelect)
        else
          _overviewGroup(
            Icons.flight_takeoff,
            [
              for (final f in trip.flights)
                (
                  '${f.dateTime} · ${f.airline}',
                  f.routeCode,
                  () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PlanFlightDetailPage(
                          tripId: widget.tripId,
                          id: f.id,
                          airline: f.airline,
                          flightNumber: f.flightNumber,
                          routeCode: f.routeCode,
                          routeCities: f.routeCities,
                          dateTime: f.dateTime,
                          terminal: f.terminal,
                          bookingRef: f.bookingRef,
                          status: f.status,
                          passengers: f.passengers,
                          passengerDetails: f.passengerDetails,
                          contactEmail: f.contactEmail,
                          contactPhone: f.contactPhone,
                          documents: f.documents,
                        ),
                      )),
                  () => _confirmDeleteFlight(f),
                ),
            ],
            trailingAdd: _addFlightOrSelect,
          ),
        const SizedBox(height: 10),
        if (trip.hotelStays.isEmpty)
          _addRow(Icons.bed_outlined, 'Add a hotel stay', onTap: _addHotelOrSelect)
        else
          _overviewGroup(
            Icons.bed_outlined,
            [
              for (final h in trip.hotelStays)
                (
                  '${h.checkIn} - ${h.checkOut}, ${h.name}',
                  h.location,
                  () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PlanHotelDetailPage(
                          name: h.name,
                          location: h.location,
                          checkIn: h.checkIn,
                          checkOut: h.checkOut,
                          guestName: h.guestName,
                          guestEmail: h.guestEmail,
                          guestPhone: h.guestPhone,
                          guestIdNumber: h.guestIdNumber,
                          specialRequests: h.specialRequests,
                        ),
                      )),
                  () => _confirmDeleteHotelStay(h),
                ),
            ],
            trailingAdd: _addHotelOrSelect,
          ),
        const SizedBox(height: 10),
        _insuranceRow(trip),
      ],
    );
  }

  // No catalog/booking link exists for this trip's insurance until someone
  // actually buys a plan for it (`trips/{tripId}.insurance`, set by
  // PaymentMethodPage on a successful purchase started from here) — so
  // tapping this row before that shows an honest "not bought yet" prompt
  // instead of jumping straight into a random plan's detail page. Once a
  // plan is bought, the row shows the real plan/policy and opens the same
  // read-only record History's Insurance tab uses.
  Widget _insuranceRow(Trip trip) {
    final insurance = trip.insurance;
    if (insurance == null) {
      return _overviewRow(
        Icons.shield_outlined,
        'Travel insurance',
        'Browse plans for this trip',
        onTap: () => _promptBrowseInsurance(trip),
      );
    }
    return _overviewRow(
      Icons.shield_outlined,
      insurance.planName,
      'Policy #${insurance.policyNumber} · ${insurance.price}',
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HistoryInsuranceDetailPage(
          planName: insurance.planName,
          policyNumber: insurance.policyNumber,
          amountPaid: insurance.price,
          coverage: insurance.coverage,
        ),
      )),
    );
  }

  Future<void> _promptBrowseInsurance(Trip trip) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'No insurance plan yet',
      message: "This trip isn't covered yet — browse plans and pick one to protect your group.",
      confirmLabel: 'Browse Plans',
      icon: Icons.shield_outlined,
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InsuranceListPage(tripId: trip.id)));
  }

  Widget _overviewIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: AppColors.navy),
    );
  }

  Widget _overviewLine(String line1, String? line2, {required VoidCallback onTap, VoidCallback? onDelete}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                  if (line2 != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(line2, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                    ),
                ],
              ),
            ),
            if (onDelete != null)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.textGrey),
                ),
              ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  // Splits the combined "23 Sep 2026 - 27 Sep 2026  ·  5 days 4 nights"
  // label onto two lines — the date range up top, the trip length as a
  // grey subtitle underneath — matching the reference design instead of
  // cramming both onto one line.
  Widget _overviewDateRow(Trip trip) {
    final label = trip.dateRangeLabel;
    if (label.isEmpty) {
      return _overviewRow(Icons.calendar_today_outlined, 'No dates set', null, onTap: () => _editDateRange(trip));
    }
    final splitAt = label.indexOf('  ·  ');
    final line1 = splitAt == -1 ? label : label.substring(0, splitAt);
    final line2 = splitAt == -1 ? null : label.substring(splitAt + 5);
    return _overviewRow(Icons.calendar_today_outlined, line1, line2, onTap: () => _editDateRange(trip));
  }

  // Every Overview entry — the date, the destination, a flight/hotel
  // group, the insurance row — sits on the same light shaded card, matching
  // the reference design (previously only the flight/hotel groups had a
  // background; the single-line rows were plain, so the page looked
  // inconsistent).
  Widget _overviewCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }

  Widget _overviewRow(IconData icon, String line1, String? line2, {required VoidCallback onTap}) {
    return _overviewCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _overviewIcon(icon),
          const SizedBox(width: 12),
          Expanded(child: _overviewLine(line1, line2, onTap: onTap)),
        ],
      ),
    );
  }

  Widget _addRow(IconData icon, String label, {required VoidCallback onTap}) {
    return _overviewCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              _overviewIcon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary))),
              const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewGroup(IconData icon, List<(String, String, VoidCallback, VoidCallback?)> lines, {VoidCallback? trailingAdd}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: _overviewIcon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < lines.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFE4E4E4)),
                  _overviewLine(lines[i].$1, lines[i].$2, onTap: lines[i].$3, onDelete: lines[i].$4),
                ],
                if (trailingAdd != null)
                  TextButton.icon(
                    onPressed: trailingAdd,
                    icon: const Icon(Icons.add, size: 15, color: AppColors.primary),
                    label: const Text('Add another', style: TextStyle(fontSize: 11.5, color: AppColors.primary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFlightDialog() async {
    final airline = TextEditingController();
    final flightNumber = TextEditingController();
    final fromCode = TextEditingController();
    final toCode = TextEditingController();
    final dateText = TextEditingController();
    final timeText = TextEditingController();
    final terminal = TextEditingController();
    final airlineFocusNode = FocusNode();
    final fromFocusNode = FocusNode();
    final toFocusNode = FocusNode();
    DateTime? pickedDate;
    TimeOfDay? pickedTime;

    final result = await showNiceFormDialog(
      context: context,
      title: 'Add Flight',
      headerIcon: Icons.flight_takeoff,
      fieldsBuilder: (ctx, setState) => [
        niceAutocompleteField(airline, 'Airline',
            options: kAirlines, icon: Icons.flight_outlined, autofocus: true, focusNode: airlineFocusNode),
        niceDialogField(flightNumber, 'Flight Number', icon: Icons.confirmation_number_outlined),
        // Search by airport/city name instead of having to already know
        // the 3-letter IATA code (see _flightLocationOptions) — the code
        // itself is pulled out of the picked suggestion on submit.
        Row(
          children: [
            Expanded(
              child: niceAutocompleteField(fromCode, 'From (city or airport)',
                  options: _flightLocationOptions, icon: Icons.flight_takeoff, focusNode: fromFocusNode),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: niceAutocompleteField(toCode, 'To (city or airport)',
                  options: _flightLocationOptions, icon: Icons.flight_land, focusNode: toFocusNode),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: niceDialogField(
                dateText,
                'Date',
                icon: Icons.event_outlined,
                readOnly: true,
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showVoyaDatePicker(
                    context: ctx,
                    initialDate: pickedDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                    title: 'Flight Date',
                  );
                  if (d != null) {
                    pickedDate = d;
                    dateText.text = formatLongDate(d);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: niceDialogField(
                timeText,
                'Time',
                icon: Icons.access_time,
                readOnly: true,
                onTap: () async {
                  final t = await showVoyaTimePicker(context: ctx, initialTime: pickedTime ?? TimeOfDay.now(), title: 'Flight Time');
                  if (t != null) {
                    pickedTime = t;
                    timeText.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  }
                },
              ),
            ),
          ],
        ),
        niceDialogField(terminal, 'Terminal (optional)', icon: Icons.meeting_room_outlined),
      ],
    );
    if (result == true && airline.text.trim().isNotEmpty) {
      final from = fromCode.text.trim().isEmpty ? '' : _extractAirportCode(fromCode.text);
      final to = toCode.text.trim().isEmpty ? '' : _extractAirportCode(toCode.text);
      final route = from.isEmpty && to.isEmpty ? '' : '$from → $to';
      final dateTime = [
        if (dateText.text.trim().isNotEmpty) dateText.text.trim(),
        if (timeText.text.trim().isNotEmpty) timeText.text.trim(),
      ].join(', ');
      await controller.addFlight(TripFlight(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        airline: airline.text.trim(),
        flightNumber: flightNumber.text.trim(),
        routeCode: route,
        routeCities: '',
        dateTime: dateTime,
        terminal: terminal.text.trim(),
        bookingRef: '',
        status: 'Confirmed',
      ));
    }
  }

  Future<void> _addHotelDialog() async {
    final name = TextEditingController();
    final location = TextEditingController();
    final checkIn = TextEditingController();
    final checkOut = TextEditingController();
    DateTime? pickedCheckIn;
    DateTime? pickedCheckOut;

    Future<void> pickStayDates(BuildContext ctx, StateSetter setState) async {
      final now = DateTime.now();
      final range = await showVoyaDateRangePicker(
        context: ctx,
        initialStart: pickedCheckIn,
        initialEnd: pickedCheckOut,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
        title: 'Check-in & Check-out',
      );
      if (range != null) {
        setState(() {
          pickedCheckIn = range.start;
          pickedCheckOut = range.end;
          checkIn.text = formatLongDate(range.start);
          checkOut.text = formatLongDate(range.end);
        });
      }
    }

    final result = await showNiceFormDialog(
      context: context,
      title: 'Add Hotel Stay',
      headerIcon: Icons.bed_outlined,
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(name, 'Hotel Name', icon: Icons.hotel_outlined, autofocus: true),
        niceDialogField(location, 'Location', icon: Icons.place_outlined),
        Row(
          children: [
            Expanded(
              child: niceDialogField(checkIn, 'Check-in', icon: Icons.login, readOnly: true, onTap: () => pickStayDates(ctx, setState)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: niceDialogField(checkOut, 'Check-out', icon: Icons.logout, readOnly: true, onTap: () => pickStayDates(ctx, setState)),
            ),
          ],
        ),
      ],
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await controller.addHotelStay(TripHotelStay(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name.text.trim(),
        location: location.text.trim(),
        checkIn: checkIn.text.trim(),
        checkOut: checkOut.text.trim(),
      ));
    }
  }

  // ---------------- "Add a flight" / "Add a hotel stay": choose first ----------------
  // Both entry points offer a real saved list and real booking history to
  // browse before falling back to typing a brand-new one by hand. Picking
  // a Saved or History item adds it straight to this trip's flight/hotel
  // list (mapped from CatalogFlight/CatalogHotel/BookingEntry's fields,
  // leaving anything they don't carry blank) — "Add manually" is there
  // for typing one in fully by hand instead.
  Widget _choiceTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
      onTap: onTap,
    );
  }

  Future<String?> _showAddOrSelectSheet(String title) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            _choiceTile(Icons.bookmark_border, 'Select from Saved', () => Navigator.of(ctx).pop('saved')),
            _choiceTile(Icons.history, 'Select from History', () => Navigator.of(ctx).pop('history')),
            _choiceTile(Icons.edit_outlined, 'Add manually', () => Navigator.of(ctx).pop('manual')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addFlightOrSelect() async {
    final choice = await _showAddOrSelectSheet('Add a flight');
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'manual':
        await _addFlightDialog();
        break;
      case 'saved':
        await _pickSavedFlight();
        break;
      case 'history':
        await _pickHistoryFlight();
        break;
    }
  }

  Future<void> _addHotelOrSelect() async {
    final choice = await _showAddOrSelectSheet('Add a hotel stay');
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'manual':
        await _addHotelDialog();
        break;
      case 'saved':
        await _pickSavedHotel();
        break;
      case 'history':
        await _pickHistoryHotel();
        break;
    }
  }

  Future<void> _pickSavedFlight() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: StreamBuilder<List<CatalogFlight>>(
            stream: CatalogRepository.instance.watchFlights(favoritedBy: '$uid#${widget.tripId}'),
            builder: (context, snapshot) {
              final flights = snapshot.data ?? const [];
              if (flights.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No saved flights for this trip yet.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: flights.length,
                itemBuilder: (context, i) {
                  final f = flights[i];
                  return ListTile(
                    leading: const Icon(Icons.flight_takeoff, color: AppColors.primary),
                    title: Text('${f.from} → ${f.to}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    subtitle: Text('${f.depTime} - ${f.arrTime} · ${f.duration}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    trailing: Text(f.displayPrice(CurrencyService.instance.lastKnownUserCurrency),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    // Picking a saved flight here means "put this on my
                    // plan" — it used to instead open the buy-a-flight
                    // detail page, which made no sense for something
                    // already saved/chosen. Adds it straight away.
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await controller.addFlight(TripFlight(
                          id: '${DateTime.now().microsecondsSinceEpoch}',
                          airline: f.airline,
                          flightNumber: '',
                          routeCode: '${f.from} → ${f.to}',
                          routeCities: '',
                          dateTime: '${f.depTime} - ${f.arrTime}',
                          terminal: '',
                          bookingRef: '',
                          status: 'Confirmed',
                        ));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add flight: $e')));
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickHistoryFlight() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: StreamBuilder<List<BookingEntry>>(
            stream: BookingRepository.instance.watchBookings(uid, type: 'flight'),
            builder: (context, snapshot) {
              final bookings = snapshot.data ?? const [];
              if (bookings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No flight history yet.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: bookings.length,
                itemBuilder: (context, i) {
                  final b = bookings[i];
                  return ListTile(
                    leading: const Icon(Icons.flight_takeoff, color: AppColors.primary),
                    title: Text(b.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    subtitle: Text(b.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    trailing: Text(b.trailing, style: const TextStyle(fontSize: 12, color: AppColors.navy)),
                    // Same as _pickSavedFlight: adds straight to the plan
                    // instead of opening a dead-end detail page.
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await controller.addFlight(TripFlight(
                          id: '${DateTime.now().microsecondsSinceEpoch}',
                          airline: '',
                          flightNumber: '',
                          routeCode: b.title,
                          routeCities: '',
                          dateTime: b.subtitle,
                          terminal: '',
                          bookingRef: '',
                          status: 'Confirmed',
                        ));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add flight: $e')));
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickSavedHotel() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: StreamBuilder<List<CatalogHotel>>(
            stream: CatalogRepository.instance.watchHotels(favoritedBy: '$uid#${widget.tripId}'),
            builder: (context, snapshot) {
              final hotels = snapshot.data ?? const [];
              if (hotels.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No saved hotels for this trip yet.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: hotels.length,
                itemBuilder: (context, i) {
                  final h = hotels[i];
                  return ListTile(
                    leading: const Icon(Icons.bed_outlined, color: AppColors.primary),
                    title: Text(h.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    subtitle: Text(h.location, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    trailing: Text(h.displayPrice(CurrencyService.instance.lastKnownUserCurrency),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    // Picking a saved hotel here means "put this on my
                    // plan" — it used to instead open the buy-a-hotel
                    // detail page. Adds it straight away.
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await controller.addHotelStay(TripHotelStay(
                          id: '${DateTime.now().microsecondsSinceEpoch}',
                          name: h.name,
                          location: h.location,
                          checkIn: '',
                          checkOut: '',
                          guestName: '',
                        ));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add hotel: $e')));
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickHistoryHotel() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: StreamBuilder<List<BookingEntry>>(
            stream: BookingRepository.instance.watchBookings(uid, type: 'hotel'),
            builder: (context, snapshot) {
              final bookings = snapshot.data ?? const [];
              if (bookings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hotel history yet.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: bookings.length,
                itemBuilder: (context, i) {
                  final b = bookings[i];
                  return ListTile(
                    leading: const Icon(Icons.bed_outlined, color: AppColors.primary),
                    title: Text(b.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    subtitle: Text(b.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    trailing: Text(b.trailing, style: const TextStyle(fontSize: 12, color: AppColors.navy)),
                    // Same as _pickSavedHotel: adds straight to the plan
                    // instead of opening a dead-end detail page.
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await controller.addHotelStay(TripHotelStay(
                          id: '${DateTime.now().microsecondsSinceEpoch}',
                          name: b.title,
                          location: b.subtitle,
                          checkIn: '',
                          checkOut: '',
                          guestName: '',
                        ));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add hotel: $e')));
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------- Overview: edit date range / destination / budget ----------------
  Future<void> _editDateRange(Trip trip) async {
    final now = DateTime.now();
    final range = await showVoyaDateRangePicker(
      context: context,
      initialStart: trip.startDate,
      initialEnd: trip.endDate,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 730)),
      title: 'Trip Dates',
    );
    if (range == null) return;
    await controller.setDates(range.start, range.end);
  }

  Future<void> _editDestination(Trip trip) async {
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchController.text.trim().toLowerCase();
          final results = query.isEmpty ? kCountries : kCountries.where((c) => c.name.toLowerCase().contains(query)).toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit destination', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search destination',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textGrey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 360,
                    child: results.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('No matching destination.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: results.length,
                            itemBuilder: (context, i) {
                              final c = results[i];
                              final selected = trip.destination == c.name;
                              return ListTile(
                                title: Text(c.name, style: const TextStyle(fontSize: 13.5)),
                                trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                                onTap: () async {
                                  Navigator.of(sheetContext).pop();
                                  await controller.setDestination(c.name);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
  }

  Future<void> _editBudget(Trip trip) async {
    final budgetController = TextEditingController(text: trip.budgetPerPerson > 0 ? trip.budgetPerPerson.toStringAsFixed(0) : '');
    final result = await showNiceFormDialog(
      context: context,
      title: 'Budget per Person',
      headerIcon: Icons.savings_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [
        // Label carries the currency ("Budget per Person (RM)") rather
        // than an inline prefixText — matches every other money field in
        // the app (Itemized Split's "Price (RM)", the expense form's
        // "Amount (RM)"), instead of being the one place with its own
        // different convention.
        niceDialogField(
          budgetController,
          'Budget per Person (RM)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
      ],
    );
    if (result != true) return;
    final parsed = double.tryParse(budgetController.text.trim());
    if (parsed == null || parsed < 0) return;
    await controller.setBudget(parsed);
  }

  Widget _dayContent(Trip trip, DayPlan day) {
    final dayIndex = controller.planIndex;
    final fullDate = trip.fullDateLabelForDay(day.day);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(fullDate.isEmpty ? 'Day ${day.day}' : 'Day ${day.day}, $fullDate',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            _dayHeaderIcon(
              Icons.auto_awesome,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI is optimising this day\'s schedule...')),
              ),
            ),
            const SizedBox(width: 14),
            _dayHeaderIcon(Icons.add, onTap: () => _addActivityDialog(trip, dayIndex)),
            const SizedBox(width: 14),
            _dayHeaderIcon(
              Icons.edit_outlined,
              active: _dayEditMode,
              onTap: () => setState(() => _dayEditMode = !_dayEditMode),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (day.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No activities planned yet', style: TextStyle(color: AppColors.textGrey))),
          )
        else
          ...day.items.map((item) => _activityCard(dayIndex, item, trip.memberNames.values.toList())),
      ],
    );
  }

  /// One of the 3 small icon buttons next to the Day header (AI optimise /
  /// add activity / toggle edit mode) — plain glyphs, no circle background,
  /// matching the reference design.
  Widget _dayHeaderIcon(IconData icon, {required VoidCallback onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 20, color: active ? AppColors.primary : AppColors.navy),
    );
  }

  String _formatTimeOfDay24(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Add Activity now offers two ways in — type one in by hand (as
  /// before), or pick something already saved (a favourited Attraction/
  /// Restaurant/Hotel for this trip) so the name/location don't need
  /// retyping. Both share the same date+time row: it defaults to
  /// whichever day's "+" was actually tapped (via [trip.dateForDay]),
  /// but is a real picker, not a fixed value, so it can be moved to any
  /// other day of the trip — doing so adds the activity to THAT day
  /// instead, worked out from the chosen date's offset from the trip's
  /// own start date (the same math [TripRepository.createTrip] used to
  /// generate the days in the first place).
  ///
  /// Replaces the old cramped [showNiceFormDialog] (narrow enough that
  /// the icon row could clip past the dialog's right edge on a smaller
  /// phone) with a full-width bottom sheet — the same pattern already
  /// used for Add Travellers/Edit Destination elsewhere on this page.
  Future<void> _addActivityDialog(Trip trip, int dayIndex) async {
    final time = TextEditingController();
    final label = TextEditingController();
    final location = TextEditingController();
    String iconKey = 'activity';
    String mode = 'manual';
    DateTime? pickedDate = trip.dateForDay(dayIndex + 1);
    TimeOfDay? pickedTime;
    ({String name, String location, String iconKey})? selectedSaved;

    final uid = AuthService.instance.currentUser?.uid ?? '';
    final favKey = '$uid#${trip.id}';
    final firstDate = trip.startDate ?? DateTime.now();
    final lastDate = trip.endDate ?? firstDate.add(const Duration(days: 365));

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Widget modeChip(String value, String labelText) {
            final selected = mode == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => setSheetState(() => mode = value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.chipGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(labelText,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
                ),
              ),
            );
          }

          Widget savedTile({required String name, required String subtitle, required IconData icon, required String iconKey2}) {
            final selected = selectedSaved?.name == name && selectedSaved?.iconKey == iconKey2;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setSheetState(() => selectedSaved = (name: name, location: subtitle, iconKey: iconKey2)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.chipGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: AppColors.primary, width: 1.2) : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(icon, size: 16, color: AppColors.navy)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
                          if (subtitle.isNotEmpty)
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                    if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            );
          }

          Future<void> pickDate() async {
            final chosen = await showDatePicker(
              context: ctx,
              initialDate: pickedDate != null && !pickedDate!.isBefore(firstDate) && !pickedDate!.isAfter(lastDate) ? pickedDate! : firstDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (chosen != null) setSheetState(() => pickedDate = chosen);
          }

          Future<void> pickTime() async {
            final chosen = await showTimePicker(context: ctx, initialTime: pickedTime ?? TimeOfDay.now());
            if (chosen != null) setSheetState(() => pickedTime = chosen);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Add Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(false),
                            child: const Icon(Icons.close, size: 20, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(children: [modeChip('manual', 'Type it in'), const SizedBox(width: 10), modeChip('saved', 'From Saved')]),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _pickerField(
                              icon: Icons.event_outlined,
                              label: pickedDate == null ? 'Date' : '${pickedDate!.day}/${pickedDate!.month}/${pickedDate!.year}',
                              onTap: pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _pickerField(
                              icon: Icons.schedule,
                              label: pickedTime == null ? 'Time (optional)' : pickedTime!.format(ctx),
                              onTap: pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (mode == 'manual') ...[
                        niceDialogField(label, 'What are you doing?', icon: Icons.edit_outlined, autofocus: true),
                        niceDialogField(location, 'Location (optional)', icon: Icons.place_outlined),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activityIcons.entries.map((e) {
                            final selected = iconKey == e.key;
                            return GestureDetector(
                              onTap: () => setSheetState(() => iconKey = e.key),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: selected ? AppColors.primary : AppColors.chipGrey,
                                child: Icon(e.value, size: 16, color: selected ? Colors.white : AppColors.navy),
                              ),
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        SizedBox(
                          height: 260,
                          child: ListView(
                            children: [
                              StreamBuilder<List<CatalogAttraction>>(
                                stream: CatalogRepository.instance.watchAttractions(favoritedBy: favKey),
                                builder: (ctx2, snap) {
                                  final items = snap.data ?? const [];
                                  if (items.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Attractions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textGrey))),
                                      ...items.map((a) => savedTile(name: a.name, subtitle: a.location, icon: Icons.local_activity_outlined, iconKey2: 'place')),
                                    ],
                                  );
                                },
                              ),
                              StreamBuilder<List<CatalogRestaurant>>(
                                stream: CatalogRepository.instance.watchRestaurants(favoritedBy: favKey),
                                builder: (ctx2, snap) {
                                  final items = snap.data ?? const [];
                                  if (items.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(padding: EdgeInsets.only(bottom: 6, top: 4), child: Text('Restaurants', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textGrey))),
                                      ...items.map((r) => savedTile(name: r.name, subtitle: r.location, icon: Icons.restaurant_outlined, iconKey2: 'food')),
                                    ],
                                  );
                                },
                              ),
                              StreamBuilder<List<CatalogHotel>>(
                                stream: CatalogRepository.instance.watchHotels(favoritedBy: favKey),
                                builder: (ctx2, snap) {
                                  final items = snap.data ?? const [];
                                  if (items.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(padding: EdgeInsets.only(bottom: 6, top: 4), child: Text('Hotels', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textGrey))),
                                      ...items.map((h) => savedTile(name: h.name, subtitle: h.location, icon: Icons.hotel_outlined, iconKey2: 'hotel')),
                                    ],
                                  );
                                },
                              ),
                              if (uid.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text('Sign in to see your saved places', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          // Validated after the sheet closes (same as the
                          // old dialog) rather than live-disabled here —
                          // the text controllers' listeners don't trigger
                          // this StatefulBuilder's setState on every
                          // keystroke, so a live-disabled button would
                          // have gone stale after typing.
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Add Activity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (added != true) return;
    final start = trip.startDate;
    var targetDayIndex = dayIndex;
    if (start != null && pickedDate != null) {
      final startMidnight = DateTime(start.year, start.month, start.day);
      final offset = pickedDate!.difference(startMidnight).inDays;
      if (offset >= 0 && offset < trip.days.length) targetDayIndex = offset;
    }
    final timeText = pickedTime == null ? '' : _formatTimeOfDay24(pickedTime!);
    if (mode == 'saved' && selectedSaved != null) {
      await controller.addActivity(
        targetDayIndex,
        time: timeText,
        label: selectedSaved!.name,
        iconKey: selectedSaved!.iconKey,
        location: selectedSaved!.location,
      );
    } else if (label.text.trim().isNotEmpty) {
      await controller.addActivity(
        targetDayIndex,
        time: timeText,
        label: label.text.trim(),
        iconKey: iconKey,
        location: location.text.trim(),
      );
    }
  }

  Widget _pickerField({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.navy, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  // Time label in a fixed-width left column, the card in an Expanded to
  // its right. The card is a plain display card now — no tap action at
  // all (it used to toggle the current user's vote on tap; the user
  // explicitly said they don't want the card to do anything when tapped,
  // so that's gone — it's a flat Container, not an InkWell). Layout:
  // icon circle, then a text column with title / (optional) location /
  // avatar-stack + fraction all left-aligned together — not the avatar
  // row pinned to the card's right edge, which is what it looked like
  // before. In edit mode (the pencil icon in the Day header) a delete
  // button still appears, as its own small tap target next to the text.
  Widget _activityCard(int dayIndex, ActivityItem item, List<String> memberNames) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_formatTime12h(item.time),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
                    child: Icon(item.icon, size: 20, color: AppColors.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        if (item.location.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 12, color: AppColors.textGrey),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(item.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _avatarStack(item.total, memberNames),
                              const SizedBox(width: 6),
                              Text('${item.voted}/${item.total}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_dayEditMode)
                    GestureDetector(
                      onTap: () => _confirmDeleteActivity(dayIndex, item),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteActivity(int dayIndex, ActivityItem item) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Remove activity?',
      message: 'This removes "${item.label}" from the day for everyone.',
      confirmLabel: 'Remove',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (confirmed) {
      await controller.removeActivity(dayIndex, item.id);
    }
  }

  Future<void> _confirmDeleteFlight(TripFlight flight) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Remove flight?',
      message: 'This removes "${flight.routeCode}" from the plan for everyone.',
      confirmLabel: 'Remove',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (confirmed) {
      await controller.removeFlight(flight.id);
    }
  }

  Future<void> _confirmDeleteHotelStay(TripHotelStay stay) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Remove hotel stay?',
      message: 'This removes "${stay.name}" from the plan for everyone.',
      confirmLabel: 'Remove',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (confirmed) {
      await controller.removeHotelStay(stay.id);
    }
  }

  /// A small stack of overlapping member-initial avatars — shows up to 3,
  /// then "+N" for the rest, next to the voted/total fraction. Reuses the
  /// same "colored circle + first letter of the name" convention already
  /// used for trip members on [GroupInfoPage] (`Colors.primaries[i % ...]`)
  /// instead of a generic, unlabelled 3-color placeholder — no profile
  /// photos in this data model, but this at least reflects the trip's
  /// actual members rather than decoration with no meaning.
  Widget _avatarStack(int total, List<String> memberNames) {
    final shown = total.clamp(0, 3);
    final extra = total - shown;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown == 0 ? 0 : 20.0 + (shown - 1) * 12.0,
          height: 20,
          child: Stack(
            children: [
              for (int i = 0; i < shown; i++)
                Positioned(
                  left: i * 12.0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.primaries[i % Colors.primaries.length],
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i < memberNames.length && memberNames[i].isNotEmpty ? memberNames[i][0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('+$extra', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
          ),
      ],
    );
  }

  /// "14:30" -> "2:30 pm" for the time header above each activity card.
  String _formatTime12h(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final h24 = int.tryParse(parts[0]);
    if (h24 == null) return time24;
    final suffix = h24 >= 12 ? 'pm' : 'am';
    var h = h24 % 12;
    if (h == 0) h = 12;
    return '$h:${parts[1]} $suffix';
  }

  // ---------------- Overview/Day pager ----------------
  // The left/right arrows sit OUTSIDE the scroll area on purpose: the whole
  // pager's width already matches the phone's own width (it's a plain
  // Container in the page's layout), and only the Overview/Day-N label
  // strip between the two arrows scrolls — so with few days everything
  // just fits, and with many days the labels scroll while both arrows stay
  // fixed and visible no matter how many days there are.
  Widget _planPager() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.navy, size: 26),
            onPressed: controller.planIndex > -1 ? () => controller.setPlanIndex(controller.planIndex - 1) : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pagerLabel('Overview', -1),
                  for (int i = 0; i < controller.days.length; i++) _pagerLabel('Day ${i + 1}', i),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.navy, size: 26),
            onPressed: controller.planIndex < controller.days.length - 1 ? () => controller.setPlanIndex(controller.planIndex + 1) : null,
          ),
        ],
      ),
    );
  }

  // Made bigger/bolder on request (was 10.5px w600 with tight 6/10 padding —
  // read as too small/thin) so roughly 4 pills sit comfortably in view
  // before the row needs to scroll, instead of cramming 6 tiny labels.
  Widget _pagerLabel(String label, int idx) {
    final selected = idx == controller.planIndex;
    return GestureDetector(
      onTap: () => controller.setPlanIndex(idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textGrey),
        ),
      ),
    );
  }

  // ================= CHAT TAB =================
  Widget _buildChatTab() {
    final myUid = AuthService.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(
          child: controller.messages.isEmpty
              ? const Center(child: Text('No messages yet — say hi!', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, i) {
                    final m = controller.messages[i];
                    final mine = m.senderId == myUid;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Padding(
                                padding: const EdgeInsets.only(left: 6, bottom: 2),
                                child: Text(m.senderName, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              ),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 260),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: mine ? AppColors.primary : const Color(0xFFDCEFFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(m.text, style: TextStyle(fontSize: 13, color: mine ? Colors.white : Colors.black)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (controller.showAttachments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentOption(Icons.camera_alt_outlined, 'Camera'),
                _attachmentOption(Icons.photo_outlined, 'Gallery'),
                _attachmentOption(Icons.location_on_outlined, 'Location'),
                _attachmentOption(Icons.auto_awesome, 'AI Summarise'),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(
            children: [
              IconButton(
                icon: Icon(controller.showAttachments ? Icons.close : Icons.add, color: AppColors.navy),
                onPressed: () => controller.toggleAttachments(),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: controller.messageController,
                    onSubmitted: (_) => controller.sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message ..',
                      hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: controller.sendMessage,
                child: const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.send, size: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attachmentOption(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.navy),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
      ],
    );
  }
}
