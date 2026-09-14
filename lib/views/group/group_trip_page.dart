import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../models/day_plan_models.dart';
import '../../models/insurance_models.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../detail/detail_page_hotel.dart';
import '../expenses/add_expense_choice_page.dart';
import '../expenses/expenses_tab.dart';
import '../insurance/insurance_plan_detail_page.dart';
import '../vote/create_vote_page.dart';
import '../vote/vote_tab.dart';
import 'group_info_page.dart';
import 'plan_flight_detail_page.dart';

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
              preferredSize: const Size.fromHeight(44),
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

  Widget _tabButton(String label, IconData icon, GroupTab tab) {
    final selected = controller.tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setTab(tab),
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? AppColors.primary : AppColors.textGrey),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
            ],
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
          child: controller.planIndex == -1 ? _overviewContent(trip) : _dayContent(controller.days[controller.planIndex]),
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
        _overviewRow(Icons.calendar_today_outlined, trip.dateRangeLabel.isEmpty ? 'No dates set' : trip.dateRangeLabel, null,
            onTap: () {}),
        const SizedBox(height: 10),
        _overviewRow(Icons.place_outlined, trip.destination.isEmpty ? 'No destination set' : trip.destination, null, onTap: () {}),
        const SizedBox(height: 10),
        _overviewRow(Icons.savings_outlined, 'RM ${trip.budgetPerPerson.toStringAsFixed(0)} per person',
            trip.interests.isEmpty ? null : trip.interests.join(' · '), onTap: () {}),
        const SizedBox(height: 10),
        if (trip.flights.isEmpty)
          _addRow(Icons.flight_takeoff, 'Add a flight', onTap: _addFlightDialog)
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
                          airline: f.airline,
                          flightNumber: f.flightNumber,
                          routeCode: f.routeCode,
                          routeCities: f.routeCities,
                          dateTime: f.dateTime,
                          terminal: f.terminal,
                          bookingRef: f.bookingRef,
                          status: f.status,
                        ),
                      )),
                ),
            ],
            trailingAdd: _addFlightDialog,
          ),
        const SizedBox(height: 10),
        if (trip.hotelStays.isEmpty)
          _addRow(Icons.bed_outlined, 'Add a hotel stay', onTap: _addHotelDialog)
        else
          _overviewGroup(
            Icons.bed_outlined,
            [
              for (final h in trip.hotelStays)
                (
                  '${h.checkIn} - ${h.checkOut}, ${h.name}',
                  h.location,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPageHotel(name: h.name, location: h.location))),
                ),
            ],
            trailingAdd: _addHotelDialog,
          ),
        const SizedBox(height: 10),
        _overviewRow(Icons.shield_outlined, 'Travel insurance', 'Browse plans for this trip',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => InsurancePlanDetailPage(plan: insurancePlans.first)))),
      ],
    );
  }

  Widget _overviewIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: AppColors.navy),
    );
  }

  Widget _overviewLine(String line1, String? line2, {required VoidCallback onTap}) {
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
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _overviewRow(IconData icon, String line1, String? line2, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            _overviewIcon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary))),
            const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _overviewGroup(IconData icon, List<(String, String, VoidCallback)> lines, {VoidCallback? trailingAdd}) {
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
                  _overviewLine(lines[i].$1, lines[i].$2, onTap: lines[i].$3),
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
    final route = TextEditingController();
    final dateTime = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Flight', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: airline, decoration: const InputDecoration(labelText: 'Airline')),
            TextField(controller: flightNumber, decoration: const InputDecoration(labelText: 'Flight Number')),
            TextField(controller: route, decoration: const InputDecoration(labelText: 'Route (e.g. KUL → NRT)')),
            TextField(controller: dateTime, decoration: const InputDecoration(labelText: 'Date & Time')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && airline.text.trim().isNotEmpty) {
      await controller.addFlight(TripFlight(
        airline: airline.text.trim(),
        flightNumber: flightNumber.text.trim(),
        routeCode: route.text.trim(),
        routeCities: '',
        dateTime: dateTime.text.trim(),
        terminal: '',
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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Hotel Stay', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Hotel Name')),
            TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
            TextField(controller: checkIn, decoration: const InputDecoration(labelText: 'Check-in date')),
            TextField(controller: checkOut, decoration: const InputDecoration(labelText: 'Check-out date')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      await controller.addHotelStay(TripHotelStay(
        name: name.text.trim(),
        location: location.text.trim(),
        checkIn: checkIn.text.trim(),
        checkOut: checkOut.text.trim(),
      ));
    }
  }

  Widget _dayContent(DayPlan day) {
    final dayIndex = controller.planIndex;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Text('Day ${day.day} - ${day.weekday}, ${day.date}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 14),
        if (day.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No activities planned yet', style: TextStyle(color: AppColors.textGrey))),
          )
        else
          ...day.items.map((item) => _activityRow(dayIndex, item)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
                onPressed: () => _addActivityDialog(dayIndex),
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text('Add Activity', style: TextStyle(color: AppColors.primary, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI is optimising this day\'s schedule...')),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                label: const Text('AI Optimise', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addActivityDialog(int dayIndex) async {
    final time = TextEditingController();
    final label = TextEditingController();
    String iconKey = 'activity';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Activity', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: time, decoration: const InputDecoration(labelText: 'Time (e.g. 14:30)')),
              TextField(controller: label, decoration: const InputDecoration(labelText: 'What are you doing?')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: activityIcons.entries.map((e) {
                  final selected = iconKey == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => iconKey = e.key),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: selected ? AppColors.primary : AppColors.chipGrey,
                      child: Icon(e.value, size: 16, color: selected ? Colors.white : AppColors.navy),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result == true && label.text.trim().isNotEmpty) {
      await controller.addActivity(dayIndex, time: time.text.trim(), label: label.text.trim(), iconKey: iconKey);
    }
  }

  Widget _activityRow(int dayIndex, ActivityItem item) {
    return InkWell(
      onTap: () => controller.toggleActivityVote(dayIndex, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 38, child: Text(item.time, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey))),
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Icon(item.icon, size: 15, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(child: Text(item.label, style: const TextStyle(fontSize: 11.5, color: Colors.black))),
            Icon(item.votedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 14, color: item.votedByMe ? AppColors.primary : AppColors.textGrey),
            const SizedBox(width: 4),
            Text('${item.voted}/${item.total}', style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  // ---------------- Overview/Day pager ----------------
  Widget _planPager() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.navy),
              onPressed: controller.planIndex > -1 ? () => controller.setPlanIndex(controller.planIndex - 1) : null,
            ),
            _pagerLabel('Overview', -1),
            for (int i = 0; i < controller.days.length; i++) _pagerLabel('Day ${i + 1}', i),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.navy),
              onPressed: controller.planIndex < controller.days.length - 1 ? () => controller.setPlanIndex(controller.planIndex + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagerLabel(String label, int idx) {
    final selected = idx == controller.planIndex;
    return GestureDetector(
      onTap: () => controller.setPlanIndex(idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey),
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
