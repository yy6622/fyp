import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../services/maps_service.dart';
import '../../theme.dart';
import '../detail/detail_page_attraction.dart';
import '../detail/detail_page_hotel.dart';
import '../detail/detail_page_restaurant.dart';
import '../expenses/add_expense_choice_page.dart';
import '../expenses/expenses_tab.dart';
import '../insurance/insurance_list_page.dart';
import '../profile/history_detail_pages.dart';
import '../shared/member_select_section.dart';
import '../shared/nice_dialog.dart';
import '../shared/nice_pickers.dart';
import '../vote/create_vote_page.dart';
import '../vote/vote_tab.dart';
import 'ai_itinerary_sheet.dart';
import 'day_timeline_view.dart';
import 'group_info_page.dart';
import 'live_conditions_card.dart';
import 'optimise_sheet.dart';
import 'plan_flight_detail_page.dart';
import 'plan_hotel_detail_page.dart';

final List<String> _flightLocationOptions = [
  for (final a in kMalaysiaAirports) '${a.city} – ${a.name} (${a.iataCode})',
  for (final g in kCountryGateways.entries) '${g.value.hotelPlaceQuery} (${g.value.flightIataCode})',
];

String _extractAirportCode(String text) {
  final match = RegExp(r'\(([A-Za-z]{2,4})\)\s*$').firstMatch(text.trim());
  return (match?.group(1) ?? text.trim()).toUpperCase();
}

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

  bool _dayEditMode = false;

  int? _editDayIndex;
  final Map<String, String> _draftTimes = {};
  final Set<String> _draftRemoved = {}; // activity ids to remove
  bool _savingDraft = false;

  bool get _hasDraftChanges => _draftTimes.isNotEmpty || _draftRemoved.isNotEmpty;

  void _startDayEdit() {
    setState(() {
      _dayEditMode = true;
      _editDayIndex = controller.planIndex;
      _draftTimes.clear();
      _draftRemoved.clear();
    });
  }

  void _endDayEdit() {
    setState(() {
      _dayEditMode = false;
      _editDayIndex = null;
      _draftTimes.clear();
      _draftRemoved.clear();
    });
  }

  List<ActivityItem> _draftItems(List<ActivityItem> items) => [
        for (final it in items)
          if (!_draftRemoved.contains(it.id))
            _draftTimes.containsKey(it.id)
                ? ActivityItem(
                    id: it.id,
                    time: _draftTimes[it.id]!,
                    icon: it.icon,
                    label: it.label,
                    location: it.location,
                    voted: it.voted,
                    total: it.total,
                    votedByMe: it.votedByMe,
                    forMemberUids: it.forMemberUids,
                  )
                : it,
      ];

  Future<bool> _saveDayEdit() async {
    final dayIndex = _editDayIndex;
    if (dayIndex == null || !_hasDraftChanges) {
      _endDayEdit();
      return true;
    }
    final changes = _draftTimes.length + _draftRemoved.length;
    setState(() => _savingDraft = true);
    try {
      for (final id in _draftRemoved) {
        await controller.removeActivity(dayIndex, id);
      }
      for (final e in _draftTimes.entries) {
        if (_draftRemoved.contains(e.key)) continue;
        await controller.updateActivityTime(dayIndex, e.key, e.value);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save your changes: $e')));
      }
      return false;
    }
    if (!mounted) return true;
    setState(() => _savingDraft = false);
    _endDayEdit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plan saved — $changes ${changes == 1 ? 'change' : 'changes'}')),
    );
    return true;
  }

  Future<bool> _confirmLeaveDayEdit() async {
    if (!_dayEditMode) return true;
    if (!_hasDraftChanges) {
      _endDayEdit();
      return true;
    }
    final n = _draftTimes.length + _draftRemoved.length;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.edit_note, color: AppColors.orange, size: 28),
              ),
              const SizedBox(height: 14),
              const Text('Save your changes?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 8),
              Text(
                'You made $n ${n == 1 ? 'change' : 'changes'} to this day. They are only kept if you save.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('save'),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop('discard'),
                  child: const Text('Discard changes', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('stay'),
                child: const Text('Keep editing', style: TextStyle(color: AppColors.textGrey)),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'save') return _saveDayEdit();
    if (choice == 'discard') {
      _endDayEdit();
      return true;
    }
    return false;
  }

  Future<void> _afterLeavingEdit(VoidCallback action) async {
    if (await _confirmLeaveDayEdit()) action();
  }

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
        return PopScope(
          canPop: !(_dayEditMode && _hasDraftChanges),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmLeaveDayEdit()) navigator.pop();
          },
          child: Scaffold(
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
                  AppAvatar(imageUrl: trip.coverImage, radius: 18, backgroundColor: const Color(0xFFD9D9D9), fallbackIcon: Icons.map_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(trip.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${trip.memberIds.length} members', style: const TextStyle(color: AppColors.textGrey, fontSize: 11)),
                      ],
                    ),
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
          body: Column(
            children: [
              AiItineraryStatusBar(controller: controller),
              OptimiseStatusBar(controller: controller),
              Expanded(child: _buildBody(trip)),
            ],
          ),
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
        ),
        );
      },
    );
  }

  Widget _tabButton(String label, IconData icon, GroupTab tab) {
    final selected = controller.tab == tab;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => _afterLeavingEdit(() => controller.setTab(tab)),
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
                  _withMembersLabel(f.routeCode, f.forMemberUids, trip.memberNames),
                  () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PlanFlightDetailPage(
                          tripId: widget.tripId,
                          id: f.id,
                          airline: f.airline,
                          flightNumber: f.flightNumber,
                          routeCode: f.routeCode,
                          routeCities: f.routeCities,
                          dateTime: f.dateTime,
                          arrivalTime: f.arrivalTime,
                          terminal: f.terminal,
                          bookingRef: f.bookingRef,
                          status: f.status,
                          passengers: f.passengers,
                          passengerDetails: f.passengerDetails,
                          contactEmail: f.contactEmail,
                          contactPhone: f.contactPhone,
                          documents: f.documents,
                          forMemberUids: f.forMemberUids,
                          memberNames: trip.memberNames,
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
                  _withMembersLabel(h.location, h.forMemberUids, trip.memberNames),
                  () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PlanHotelDetailPage(
                          tripId: widget.tripId,
                          id: h.id,
                          name: h.name,
                          location: h.location,
                          checkIn: h.checkIn,
                          checkOut: h.checkOut,
                          bookingRef: h.bookingRef,
                          status: h.status,
                          guestName: h.guestName,
                          guestEmail: h.guestEmail,
                          guestPhone: h.guestPhone,
                          guestIdNumber: h.guestIdNumber,
                          specialRequests: h.specialRequests,
                          refId: h.refId,
                          documents: h.documents,
                          forMemberUids: h.forMemberUids,
                          memberNames: trip.memberNames,
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
          transactionId: insurance.transactionId,
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

  String _withMembersLabel(String base, List<String> forMemberUids, Map<String, String> memberNames) {
    final label = forMembersLabel(forMemberUids, memberNames);
    return label.isEmpty ? base : '$base · $label';
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
          final results = query.isEmpty ? kDestinationCountries : kDestinationCountries.where((c) => c.name.toLowerCase().contains(query)).toList();
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(fullDate.isEmpty ? 'Day ${day.day}' : 'Day ${day.day}, $fullDate',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ),
              if (!_dayEditMode) ...[
                _dayHeaderIcon(
                  Icons.auto_awesome,
                  onTap: () => showOptimiseModeSheet(context, controller, dayIndex: dayIndex, dayNumber: day.day),
                ),
                const SizedBox(width: 14),
                _dayHeaderIcon(Icons.add, onTap: () => _addActivityDialog(trip, dayIndex)),
                const SizedBox(width: 14),
              ] else ...[
                GestureDetector(
                  onTap: _savingDraft ? null : () => _confirmLeaveDayEdit(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              _dayEditMode
                  ? _dayHeaderSaveButton(onTap: _savingDraft ? () {} : () => _saveDayEdit())
                  : _dayHeaderIcon(
                      Icons.edit_outlined,
                      onTap: _startDayEdit,
                    ),
            ],
          ),
          const SizedBox(height: 14),
          LiveConditionsCard(
            key: ValueKey('live-conditions-${day.day}'),
            destination: trip.destination,
            forDate: trip.dateForDay(day.day),
            activities: day.items,
            controller: controller,
            dayIndex: dayIndex,
            dayNumber: day.day,
          ),
          if (day.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No activities planned yet', style: TextStyle(color: AppColors.textGrey))),
            )
          else if (_dayEditMode) ...[
            if (_hasDraftChanges)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Unsaved: ${_draftTimes.length} moved, ${_draftRemoved.length} removed — tap Save to keep them.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.orange),
                ),
              ),
            Expanded(
              child: DayTimelineView(
                items: _draftItems(day.items),
                onTimeChanged: (item, newTime) => setState(() {
                  final original = day.items.where((it) => it.id == item.id).map((it) => it.time).firstOrNull;
                  if (original == newTime) {
                    _draftTimes.remove(item.id);
                  } else {
                    _draftTimes[item.id] = newTime;
                  }
                }),
                onDelete: (item) => setState(() => _draftRemoved.add(item.id)),
              ),
            ),
          ]
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: _dayItemsWithTransport(day.items, trip),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayHeaderIcon(IconData icon, {required VoidCallback onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 20, color: active ? AppColors.primary : AppColors.navy),
    );
  }

  Widget _dayHeaderSaveButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 15, color: Colors.white),
            SizedBox(width: 4),
            Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay24(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _addActivityDialog(Trip trip, int dayIndex) async {
    final label = TextEditingController();
    final location = TextEditingController();
    String iconKey = 'activity';
    String mode = 'manual';
    DateTime? pickedDate = trip.dateForDay(dayIndex + 1);
    TimeOfDay? pickedTime;
    ({String name, String location, String iconKey})? selectedSaved;
    Set<String> selectedMemberUids = trip.memberIds.toSet();

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
                      if (trip.memberIds.length > 1) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFECECEC)),
                        const SizedBox(height: 14),
                        MemberSelectSection(
                          memberNames: trip.memberNames,
                          selected: selectedMemberUids,
                          onChanged: (v) => setSheetState(() => selectedMemberUids = v),
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
    final forMemberUids = selectedMemberUids.toList();
    if (mode == 'saved' && selectedSaved != null) {
      await controller.addActivity(
        targetDayIndex,
        time: timeText,
        label: selectedSaved!.name,
        iconKey: selectedSaved!.iconKey,
        location: selectedSaved!.location,
        forMemberUids: forMemberUids,
      );
    } else if (label.text.trim().isNotEmpty) {
      await controller.addActivity(
        targetDayIndex,
        time: timeText,
        label: label.text.trim(),
        iconKey: iconKey,
        location: location.text.trim(),
        forMemberUids: forMemberUids,
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

  Widget _activityCard(ActivityItem item, Trip trip) {
    final memberNames = trip.memberNames.values.toList();
    final forLabel = forMembersLabel(item.forMemberUids, trip.memberNames);
    final hotel = controller.hotelForActivity(item);
    final attraction = hotel == null ? controller.attractionForActivity(item) : null;
    final restaurant = hotel == null && attraction == null ? controller.restaurantForActivity(item) : null;
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
            child: GestureDetector(
              onTap: _activityDetailTap(hotel, attraction, restaurant),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(16)),
                child: hotel != null
                    ? _activityHotelBody(item, hotel, forLabel, memberNames)
                    : attraction != null
                        ? _activityAttractionBody(item, attraction, forLabel, memberNames)
                        : restaurant != null
                            ? _activityRestaurantBody(item, restaurant, forLabel, memberNames)
                            : _activityPlainBody(item, forLabel, memberNames),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _dayItemsWithTransport(List<ActivityItem> items, Trip trip) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      widgets.add(_activityCard(items[i], trip));
      if (i == items.length - 1) continue;
      final from = _effectiveLocationFor(items[i]);
      final to = _effectiveLocationFor(items[i + 1]);
      if (from.isNotEmpty && to.isNotEmpty && from.toLowerCase() != to.toLowerCase()) {
        final fromPoint = _effectivePointFor(items[i]);
        final toPoint = _effectivePointFor(items[i + 1]);
        final km = (fromPoint != null && toPoint != null) ? MapsService.kmBetween(fromPoint, toPoint) : null;
        widgets.add(_transportRow(from, to, MapsService.suggest(km)));
      }
    }
    return widgets;
  }

  String _effectiveLocationFor(ActivityItem item) {
    final hotel = controller.hotelForActivity(item);
    if (hotel != null) return hotel.location;
    final attraction = controller.attractionForActivity(item);
    if (attraction != null) return attraction.location.isNotEmpty ? attraction.location : attraction.category;
    final restaurant = controller.restaurantForActivity(item);
    if (restaurant != null) return restaurant.location;
    return item.location;
  }


  LatLng? _effectivePointFor(ActivityItem item) {
    final attraction = controller.attractionForActivity(item);
    if (attraction?.lat != null && attraction?.lng != null) return LatLng(attraction!.lat!, attraction.lng!);
    final restaurant = controller.restaurantForActivity(item);
    if (restaurant?.lat != null && restaurant?.lng != null) return LatLng(restaurant!.lat!, restaurant.lng!);
    return null;
  }

  Widget _transportRow(String from, String to, TransportSuggestion suggestion) {
    final icon = switch (suggestion.mode) {
      SuggestedTravelMode.walk => Icons.directions_walk,
      SuggestedTravelMode.drive => Icons.directions_car_outlined,
      SuggestedTravelMode.unknown => Icons.directions_outlined,
    };
    final label = suggestion.etaMinutes != null
        ? '${suggestion.label} · ${suggestion.etaMinutes} min to $to'
        : '${suggestion.label} to $to';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 66),
          Expanded(
            child: GestureDetector(
              onTap: () => _openDirectionsInMaps(from, to, suggestion.googleMapsTravelMode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new, size: 13, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectionsInMaps(String from, String to, String travelMode) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${Uri.encodeComponent(from)}'
      '&destination=${Uri.encodeComponent(to)}'
      '&travelmode=$travelMode',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  VoidCallback? _activityDetailTap(CatalogHotel? hotel, CatalogAttraction? attraction, CatalogRestaurant? restaurant) {
    if (hotel != null) {
      return () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetailPageHotel(
              hotelId: hotel.id,
              name: hotel.name,
              location: hotel.location,
              ratingLabel: '${hotel.rating}(${hotel.reviews})',
              pricePerNight: hotel.displayPrice(CurrencyService.instance.lastKnownUserCurrency),
              image: hotel.image,
              tripId: widget.tripId,
              amenities: hotel.amenities,
            ),
          ));
    }
    if (attraction != null) {
      return () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetailPageAttraction(attraction: attraction, saved: true),
          ));
    }
    if (restaurant != null) {
      return () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetailPageRestaurant(restaurant: restaurant, saved: true),
          ));
    }
    return null;
  }

  Widget _activityHotelBody(ActivityItem item, CatalogHotel hotel, String forLabel, List<String> memberNames) {
    final price = hotel.displayPrice(CurrencyService.instance.lastKnownUserCurrency);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityThumb(hotel.image, Icons.hotel_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hotel.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              if (hotel.rating.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: _activityRatingRow(hotel.rating, hotel.reviews)),
              if (hotel.location.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: _activityLocationRow(hotel.location)),
              if (price.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$price per night', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              _activityFooter(item, forLabel, memberNames),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityAttractionBody(ActivityItem item, CatalogAttraction attraction, String forLabel, List<String> memberNames) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityThumb(attraction.image, Icons.attractions_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(attraction.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              if (attraction.rating.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: _activityRatingRow(attraction.rating, attraction.reviews)),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _activityLocationRow(attraction.location.isNotEmpty ? attraction.location : attraction.category),
              ),
              if (attraction.price.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(attraction.price, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              _activityFooter(item, forLabel, memberNames),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityRestaurantBody(ActivityItem item, CatalogRestaurant restaurant, String forLabel, List<String> memberNames) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurant.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              if (restaurant.rating.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: _activityRatingRow(restaurant.rating, restaurant.reviews)),
              if (restaurant.location.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: _activityLocationRow(restaurant.location)),
              if (restaurant.priceRange.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(restaurant.priceRange, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              _activityFooter(item, forLabel, memberNames),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityPlainBody(ActivityItem item, String forLabel, List<String> memberNames) {
    return Row(
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
              Text(item.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              if (item.location.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: _activityLocationRow(item.location)),
              _activityFooter(item, forLabel, memberNames),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityFooter(ActivityItem item, String forLabel, List<String> memberNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (forLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(forLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        if (_activityMemberUids(item).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _avatarStack(_activityMemberUids(item)),
          ),
      ],
    );
  }

  Widget _activityThumb(String url, IconData icon) {
    if (url.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.textGrey, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: AppColors.chipGrey, child: Icon(icon, color: AppColors.textGrey, size: 20)),
      ),
    );
  }

  Widget _activityRatingRow(String rating, String reviews) {
    return Row(
      children: [
        const Icon(Icons.star, size: 12, color: AppColors.orange),
        const SizedBox(width: 3),
        Text(rating, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black)),
        if (reviews.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text('($reviews)', style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
        ],
      ],
    );
  }

  Widget _activityLocationRow(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 12, color: AppColors.textGrey),
        const SizedBox(width: 3),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey))),
      ],
    );
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

  List<String> _activityMemberUids(ActivityItem item) =>
      effectiveActivityMembers(item, controller.trip?.memberIds ?? const <String>[]);

  Widget _avatarStack(List<String> uids) {
    final shown = uids.take(4).toList();
    final extra = uids.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.isEmpty ? 0 : 22.0 + (shown.length - 1) * 14.0,
          height: 22,
          child: Stack(
            children: [
              for (int i = 0; i < shown.length; i++)
                Positioned(
                  left: i * 14.0,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: UserAvatar(uid: shown[i], radius: 9.5),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('+$extra', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
          ),
      ],
    );
  }

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

  Widget _planPager() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.navy, size: 26),
            onPressed: controller.planIndex > -1 ? () => _afterLeavingEdit(() => controller.setPlanIndex(controller.planIndex - 1)) : null,
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
            onPressed: controller.planIndex < controller.days.length - 1
                ? () => _afterLeavingEdit(() => controller.setPlanIndex(controller.planIndex + 1))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _pagerLabel(String label, int idx) {
    final selected = idx == controller.planIndex;
    return GestureDetector(
      onTap: () => idx == controller.planIndex ? null : _afterLeavingEdit(() => controller.setPlanIndex(idx)),
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
                  reverse: true,
                  itemCount: controller.messages.length,
                  itemBuilder: (context, i) {
                    final m = controller.messages[controller.messages.length - 1 - i];
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
                            if (m.isImage)
                              GestureDetector(
                                onTap: () => _openFullScreenImage(context, m.imageUrl),
                                onLongPress: mine ? () => _showMessageOptions(m) : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    m.imageUrl,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) => progress == null
                                        ? child
                                        : Container(
                                            width: 200,
                                            height: 200,
                                            color: const Color(0xFFF0F0F0),
                                            alignment: Alignment.center,
                                            child: const CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                    errorBuilder: (context, error, stack) => Container(
                                      width: 200,
                                      height: 200,
                                      color: const Color(0xFFF0F0F0),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image_outlined, color: AppColors.textGrey),
                                    ),
                                  ),
                                ),
                              )
                            else if (m.isLocation)
                              GestureDetector(
                                onTap: () => _openLocationInMaps(m.lat!, m.lng!),
                                onLongPress: mine ? () => _showMessageOptions(m) : null,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 260),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: mine ? AppColors.primary : const Color(0xFFDCEFFF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, size: 18, color: mine ? Colors.white : AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text('Location shared — tap to view',
                                          style: TextStyle(fontSize: 12.5, color: mine ? Colors.white : Colors.black)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onLongPress: mine ? () => _showMessageOptions(m) : null,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 260),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: mine ? AppColors.primary : const Color(0xFFDCEFFF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(m.text, style: TextStyle(fontSize: 13, color: mine ? Colors.white : Colors.black)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (controller.sendingAttachment)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary, backgroundColor: Color(0xFFF0F0F0)),
          ),
        if (controller.showAttachments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentOption(Icons.camera_alt_outlined, 'Camera', onTap: () => _sendImageAttachment(context, ImageSource.camera)),
                _attachmentOption(Icons.photo_outlined, 'Gallery', onTap: () => _sendImageAttachment(context, ImageSource.gallery)),
                _attachmentOption(Icons.location_on_outlined, 'Location', onTap: () => _sendLocationAttachment(context)),
                _attachmentOption(Icons.auto_awesome, 'AI Summarise', onTap: () => showAiItinerarySheet(context, controller)),
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

  Future<void> _sendImageAttachment(BuildContext context, ImageSource source) async {
    final error = await controller.sendImageMessage(source);
    if (!context.mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _sendLocationAttachment(BuildContext context) async {
    final error = await controller.sendLocationMessage();
    if (!context.mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _openLocationInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
      ),
    ));
  }

  void _showMessageOptions(TripMessage m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.isImage && !m.isLocation)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.navy),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _editMessageDialog(m);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteMessage(m);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessageDialog(TripMessage m) async {
    final textController = TextEditingController(text: m.text);
    final result = await showNiceFormDialog(
      context: context,
      title: 'Edit Message',
      headerIcon: Icons.edit_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [niceDialogField(textController, 'Message', autofocus: true, maxLines: 4)],
    );
    if (result == true) {
      await controller.editMessage(m.id, textController.text);
    }
  }

  Future<void> _deleteMessage(TripMessage m) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Delete Message',
      message: 'This message will be removed for everyone in the group.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever,
      destructive: true,
    );
    if (!confirmed) return;
    await controller.deleteMessage(m.id);
  }

  Widget _attachmentOption(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.navy),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
