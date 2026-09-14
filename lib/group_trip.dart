import 'package:flutter/material.dart';

import 'create_plan.dart';
import 'detail_pages.dart';
import 'group_settings.dart';
import 'expenses_flow.dart';
import 'insurance.dart';
import 'theme.dart';
import 'vote.dart';

// ---------------------------------------------------------------------
// New Plan chooser (reached from the Plan tab's "+" button)
// ---------------------------------------------------------------------
class NewPlanPage extends StatelessWidget {
  const NewPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('New Plan', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 20)),
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      body: Column(
        children: [
          _tile(context, 'Create New Plan', 'Start a new trip with friends',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePlanWizard()))),
          _tile(context, 'Join with invite link', 'Enter invite link to join', () {}),
          _tile(context, 'Scan QR code', 'Scan to join a group', () {}),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFFDFDE0), borderRadius: BorderRadius.circular(22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navy),
          ],
        ),
      ),
    );
  }

}

// ---------------------------------------------------------------------
// Group trip screen: Plan / Chat / Expenses / Vote tabs
// ---------------------------------------------------------------------
enum GroupTab { plan, chat, expenses, vote }

class GroupTripPage extends StatefulWidget {
  static const routeName = '/groupTrip';

  final String groupName;
  final GroupTab initialTab;
  const GroupTripPage({super.key, this.groupName = 'Japan Trips', this.initialTab = GroupTab.plan});

  @override
  State<GroupTripPage> createState() => _GroupTripPageState();
}

class _GroupTripPageState extends State<GroupTripPage> {
  late GroupTab _tab = widget.initialTab;
  bool _overviewExpanded = true;
  int? _expandedDay = 0;

  final List<_DayPlan> _days = const [
    _DayPlan(day: 1, weekday: 'Mon', date: '12 Jun', items: [
      _ActivityItem(time: '10:30', icon: Icons.flight_land, label: 'Arrive to Narita Airport (NRT)', voted: 5, total: 5),
      _ActivityItem(time: '14:30', icon: Icons.hotel_outlined, label: 'Check-in L Hotel', voted: 5, total: 5),
      _ActivityItem(time: '16:30', icon: Icons.shopping_bag_outlined, label: 'Shibaya Shopping Mall', voted: 4, total: 5),
      _ActivityItem(time: '19:30', icon: Icons.restaurant_outlined, label: 'Dinner at Uobei Shibuya', voted: 5, total: 5),
    ]),
    _DayPlan(day: 2, weekday: 'Tue', date: '13 Jun', items: []),
    _DayPlan(day: 3, weekday: 'Wed', date: '14 Jun', items: []),
    _DayPlan(day: 4, weekday: 'Thu', date: '15 Jun', items: []),
    _DayPlan(day: 5, weekday: 'Fri', date: '16 Jun', items: []),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupInfoPage())),
          child: Row(
            children: [
              const CircleAvatar(radius: 18, backgroundColor: Color(0xFFD9D9D9)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.groupName, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('7 members', style: TextStyle(color: AppColors.textGrey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.navy),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupInfoPage())),
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
      body: _buildBody(),
      floatingActionButton: _tab == GroupTab.expenses
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddExpenseChoicePage()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : _tab == GroupTab.vote
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateVotePage()),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
    );
  }

  Widget _tabButton(String label, IconData icon, GroupTab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
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

  Widget _buildBody() {
    switch (_tab) {
      case GroupTab.plan:
        return _buildPlanTab();
      case GroupTab.chat:
        return _buildChatTab();
      case GroupTab.expenses:
        return const ExpensesTab();
      case GroupTab.vote:
        return const VoteTab();
    }
  }

  // ================= PLAN TAB =================
  Widget _buildPlanTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _overviewCard(),
        const SizedBox(height: 12),
        ..._days.map((d) => _dayCard(d)),
      ],
    );
  }

  Widget _overviewCard() {
    return Container(
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _overviewExpanded = !_overviewExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 18, color: AppColors.navy),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Trip Overview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  Icon(_overviewExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.navy),
                ],
              ),
            ),
          ),
          if (_overviewExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _overviewRow(Icons.calendar_today_outlined, '12 - 19 June 2026', '7 days 6 night', onTap: null),
                  _overviewRow(Icons.place_outlined, 'Tokyo - Mount Fuji - Kyoto - Osaka', null, onTap: null),
                  _overviewRow(Icons.flight_takeoff, '12 June 2026, 13:30', '11900 Bayan Lepas, Penang',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanFlightDetailPage()))),
                  _overviewRow(Icons.flight_land, '19 June 2026, 22:00', 'Handeduko, Ota City, Tokyo 144-0041',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanFlightDetailPage()))),
                  _overviewRow(Icons.bed_outlined, '12 June 2026, L Hotel', '11900 Bayan Lepas, Penang',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetailPageHotel()))),
                  _overviewRow(Icons.bed_outlined, '16 June 2026, M Hotel', 'Handeduko, Ota City, Tokyo 144-0041',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetailPageHotel()))),
                  _overviewRow(Icons.shield_outlined, '112233445566778899', 'Allianz Travel',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => InsurancePlanDetailPage(plan: insurancePlans.first)))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _overviewRow(IconData icon, String line1, String? line2, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.navy),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line1, style: const TextStyle(fontSize: 12.5, color: Colors.black)),
                  if (line2 != null) Text(line2, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(_DayPlan day) {
    final expanded = _expandedDay == day.day - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DayDetailPage(days: _days, initialIndex: day.day - 1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Text(
                        'Day ${day.day} - ${day.weekday}, ${day.date}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.navy),
                  onPressed: () => setState(() => _expandedDay = expanded ? null : day.day - 1),
                ),
              ],
            ),
            if (expanded && day.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    ...day.items.map((item) => _activityRow(item)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Opening activity picker...')),
                            ),
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(_ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 38, child: Text(item.time, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey))),
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Icon(item.icon, size: 15, color: AppColors.navy),
          const SizedBox(width: 8),
          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 11.5, color: Colors.black))),
          _voteAvatars(item.voted, item.total),
        ],
      ),
    );
  }

  Widget _voteAvatars(int voted, int total) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 18,
          child: Stack(
            children: List.generate(voted.clamp(0, 3), (i) {
              return Positioned(
                left: i * 11.0,
                child: CircleAvatar(radius: 9, backgroundColor: Colors.primaries[i % Colors.primaries.length]),
              );
            }),
          ),
        ),
        Text('$voted/$total', style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
      ],
    );
  }

  // ================= CHAT TAB =================
  bool _showAttachments = false;

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('2 March 2026', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ),
              ),
              _chatBubble('Let book Airbnb tonight!', '14:20'),
              const SizedBox(height: 10),
              _hotelSuggestionBubble(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _sharedHotelBubble(),
              ),
            ],
          ),
        ),
        if (_showAttachments)
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
                icon: Icon(_showAttachments ? Icons.close : Icons.add, color: AppColors.navy),
                onPressed: () => setState(() => _showAttachments = !_showAttachments),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a message ..',
                      hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.send, size: 16, color: Colors.white)),
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

  Widget _chatBubble(String text, String time) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const CircleAvatar(radius: 14, backgroundColor: Color(0xFFD9D9D9)),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFDCEFFF), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 13, color: Colors.black)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hotelSuggestionBubble() {
    final options = [
      ('L Hotel', 0.714, true),
      ('M Hotel', 0.0, false),
      ('K Hotel', 0.296, false),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 14 * 2 + 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFDCEFFF), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hotel Suggestion', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 10),
                ...options.map((o) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 10, backgroundColor: Color(0xFFD9D9D9)),
                          const SizedBox(width: 8),
                          SizedBox(width: 44, child: Text(o.$1, style: const TextStyle(fontSize: 11.5, color: Colors.black))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: o.$2,
                                minHeight: 6,
                                backgroundColor: Colors.white,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (o.$3) const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                          Text('${(o.$2 * 100).round()}%', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                        ],
                      ),
                    )),
                const SizedBox(height: 4),
                const Align(alignment: Alignment.centerRight, child: Text('23:24', style: TextStyle(fontSize: 9, color: AppColors.textGrey))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sharedHotelBubble() {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('I found this hotel look great', style: TextStyle(fontSize: 12, color: Colors.black)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppImage('assets/images/adventure_bg.jpg', height: 90, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          const Text('L Hotel, Khon Kaen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
          Row(
            children: const [
              Icon(Icons.star, size: 12, color: AppColors.orange),
              SizedBox(width: 4),
              Text('4.8(1.2k)', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ],
          ),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(text: 'RM 899 ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                TextSpan(text: 'per night', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Align(alignment: Alignment.centerRight, child: Text('23:24', style: TextStyle(fontSize: 9, color: AppColors.textGrey))),
        ],
      ),
    );
  }
}

class _DayPlan {
  final int day;
  final String weekday;
  final String date;
  final List<_ActivityItem> items;
  const _DayPlan({required this.day, required this.weekday, required this.date, required this.items});
}

class _ActivityItem {
  final String time;
  final IconData icon;
  final String label;
  final int voted;
  final int total;
  const _ActivityItem({required this.time, required this.icon, required this.label, required this.voted, required this.total});
}

// ---------------------------------------------------------------------
// Full day detail page, swipeable via bottom day pager
// ---------------------------------------------------------------------
class DayDetailPage extends StatefulWidget {
  final List<_DayPlan> days;
  final int initialIndex;
  const DayDetailPage({super.key, required this.days, required this.initialIndex});

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final day = widget.days[_index];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: Text('Day ${day.day}, 12 June 2026', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.navy),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI is optimising this day\'s schedule...')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.navy),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening activity picker...')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.navy),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit mode is coming soon')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: day.items.map((item) => _activityCard(item)).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.navy),
                  onPressed: _index > 0 ? () => setState(() => _index--) : null,
                ),
                Expanded(child: _pagerLabel('Overview', -1)),
                for (int i = 0; i < widget.days.length; i++) Expanded(child: _pagerLabel('Day ${i + 1}', i)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.navy),
                  onPressed: _index < widget.days.length - 1 ? () => setState(() => _index++) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagerLabel(String label, int idx) {
    final selected = idx == _index;
    return GestureDetector(
      onTap: idx >= 0 ? () => setState(() => _index = idx) : () => Navigator.of(context).maybePop(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _activityCard(_ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(_toAmPm(item.time), style: const TextStyle(fontSize: 12, color: Colors.black))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: Color(0xFFD9E8F0), shape: BoxShape.circle),
                    child: Icon(item.icon, size: 16, color: AppColors.navy),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 2),
                        Row(
                          children: const [
                            Icon(Icons.location_on_outlined, size: 11, color: AppColors.textGrey),
                            SizedBox(width: 2),
                            Expanded(
                              child: Text('1-1 Furugome, Narita, Chiba 282-0004',
                                  style: TextStyle(fontSize: 9.5, color: AppColors.textGrey), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 18,
                        child: Stack(
                          children: List.generate(item.voted.clamp(0, 3), (i) {
                            return Positioned(left: i * 11.0, child: CircleAvatar(radius: 9, backgroundColor: Colors.primaries[i % Colors.primaries.length]));
                          }),
                        ),
                      ),
                      Text('${item.voted}/${item.total}', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _toAmPm(String time24) {
    final parts = time24.split(':');
    var h = int.parse(parts[0]);
    final m = parts[1];
    final suffix = h >= 12 ? 'pm' : 'am';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    return '$h:$m $suffix';
  }
}

// ---------------------------------------------------------------------
// Plan_Flight_Detail — flight card inside a group's itinerary
// ---------------------------------------------------------------------
class PlanFlightDetailPage extends StatefulWidget {
  const PlanFlightDetailPage({super.key});

  @override
  State<PlanFlightDetailPage> createState() => _PlanFlightDetailPageState();
}

class _PlanFlightDetailPageState extends State<PlanFlightDetailPage> {
  bool _passengerTab = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Flight', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.navy),
            onSelected: (_) {},
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'private', child: Text('Set to private')),
              PopupMenuItem(value: 'shift', child: Text('Shift to Plans')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: _tab('Detail', !_passengerTab)),
              Expanded(child: _tab('Passenger', _passengerTab)),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFECECEC)),
          Expanded(
            child: _passengerTab ? _passengerContent() : _detailContent(),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _passengerTab = label == 'Passenger'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2))),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey)),
      ),
    );
  }

  Widget _detailContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('FLIGHT INFORMATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              _field('Airline', 'Malaysia Airlines'),
              _field('Flight Number', 'MH0521'),
              _field('Route', 'KUL → KIX (Kuala Lumpur → Osaka)'),
              _field('Date & Time', '12 June 2026, 13:30'),
              _field('Terminal', 'Terminal 1'),
              _field('Booking Reference', 'ABC123'),
              _field('Status', 'Confirmed', last: true),
            ],
          ),
        ),
      ],
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
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _passengerContent() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Passenger name', style: TextStyle(fontSize: 13, color: Colors.black))),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
