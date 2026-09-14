import 'package:flutter/material.dart';

import 'group_trip.dart';
import 'theme.dart';

enum PlanTab { all, plan, voting, expenses }

extension _PlanTabMeta on PlanTab {
  String get label {
    switch (this) {
      case PlanTab.all:
        return 'All';
      case PlanTab.plan:
        return 'Plan';
      case PlanTab.voting:
        return 'Voting';
      case PlanTab.expenses:
        return 'Expenses';
    }
  }

  IconData get icon {
    switch (this) {
      case PlanTab.all:
        return Icons.grid_view_rounded;
      case PlanTab.plan:
        return Icons.sync_alt;
      case PlanTab.voting:
        return Icons.how_to_vote_outlined;
      case PlanTab.expenses:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  PlanTab _selectedTab = PlanTab.all;

  final List<_VotingItem> _votingItems = const [
    _VotingItem(
      title: 'Tokyo Trips',
      subtitle: 'Hotel voting ongoing',
      date: '2 Jun, 14:00',
      votes: '5/7 voted',
      image: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400',
    ),
    _VotingItem(
      title: 'Tokyo Trips',
      subtitle: 'Hotel voting ongoing',
      date: '2 Jun, 14:00',
      votes: '5/7 voted',
      image: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=400',
    ),
    _VotingItem(
      title: 'Tokyo Trips',
      subtitle: 'Hotel voting ongoing',
      date: '2 Jun, 14:00',
      votes: '5/7 voted',
      image: 'https://images.unsplash.com/photo-1554797589-7241bb691973?w=400',
    ),
  ];

  final List<_PlanGroup> _planGroups = const [
    _PlanGroup(
      title: 'Japan Trips',
      members: '7 members',
      timeAgo: '2m ago',
      lastMessage: 'Teoh: Let book Airbnb tonight!',
      unread: 3,
      tags: ['Plan Updated', 'Expenses Updated', 'Poll Ongoing'],
    ),
    _PlanGroup(
      title: 'Japan Trips',
      members: '7 members',
      timeAgo: '2m ago',
      lastMessage: 'Teoh: Let book Airbnb tonight!',
      unread: 99,
      tags: ['Plan Updated', 'Expenses Updated', 'Poll Ongoing'],
    ),
    _PlanGroup(
      title: 'Japan Trips',
      members: '7 members',
      timeAgo: '2m ago',
      lastMessage: 'Teoh: Let book Airbnb tonight!',
      unread: 3,
      tags: ['Plan Updated', 'Expenses Updated', 'Poll Ongoing'],
    ),
  ];

  // Whether each section should show for the currently-selected tab.
  // "All" shows everything; every other tab shows only its own section,
  // which is the behaviour that was missing before — selecting a tab
  // changed its highlight but never actually filtered the page.
  bool get _showVoting => _selectedTab == PlanTab.all || _selectedTab == PlanTab.voting;
  bool get _showOwe => _selectedTab == PlanTab.all || _selectedTab == PlanTab.expenses;
  bool get _showGroups =>
      _selectedTab == PlanTab.all || _selectedTab == PlanTab.plan || _selectedTab == PlanTab.expenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildTabChips(),
            const SizedBox(height: 20),
            if (_showVoting) ...[
              _buildSectionHeader('Current Voting', showIcon: Icons.how_to_vote_outlined),
              const SizedBox(height: 12),
              _buildVotingList(),
              const SizedBox(height: 18),
            ],
            if (_showOwe) ...[
              _buildOweCard(),
              const SizedBox(height: 20),
            ],
            if (_showGroups) ...[
              _buildSectionHeader(
                _selectedTab == PlanTab.expenses ? 'Group Expenses' : 'Planning',
                showIcon: _selectedTab == PlanTab.expenses
                    ? Icons.account_balance_wallet_outlined
                    : Icons.sync_alt,
              ),
              const SizedBox(height: 12),
              ..._planGroups.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildPlanGroupCard(
                  g,
                  tab: _selectedTab == PlanTab.expenses ? GroupTab.expenses : GroupTab.plan,
                ),
              )),
            ],
            if (!_showVoting && !_showOwe && !_showGroups) _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.textGrey),
          SizedBox(height: 12),
          Text('Nothing here yet', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
        ],
      ),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              SizedBox(height: 4),
              Text(
                'Build Your Trip Together',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewPlanPage()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Search bar ----------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textGrey, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search plans',
                  hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Tab chips ----------------
  // Scrollable instead of a plain Row: a plain Row has no way to shrink
  // below the natural width of 4 icon+label chips, so on narrower phones
  // it overflowed off the right edge of the screen. A horizontal
  // ListView never overflows — it scrolls instead — and still lets every
  // chip stay tappable.
  Widget _buildTabChips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: PlanTab.values.map((tab) {
          final selected = tab == _selectedTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.chipGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 15, color: selected ? Colors.white : AppColors.textGrey),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- Section header ----------------
  Widget _buildSectionHeader(String title, {IconData? showIcon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (showIcon != null) ...[
                Icon(showIcon, size: 17, color: AppColors.navy),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
            ],
          ),
          const Text(
            'View All',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  // ---------------- Current voting ----------------
  Widget _buildVotingList() {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _votingItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildVotingCard(_votingItems[index]),
      ),
    );
  }

  Widget _buildVotingCard(_VotingItem item) {
    return GestureDetector(
      onTap: () => _openGroup(context, tab: GroupTab.vote),
      child: Container(
      width: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              item.image,
              height: 150,
              width: 130,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
              child: Text(item.date, style: const TextStyle(color: Colors.white, fontSize: 8)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(item.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 34,
                        height: 14,
                        child: Stack(
                          children: List.generate(3, (i) {
                            return Positioned(
                              left: i * 10.0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: [Colors.orange, Colors.blue, Colors.pink][i],
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(item.votes, style: const TextStyle(color: Colors.white, fontSize: 7.5)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openGroup(BuildContext context, {GroupTab tab = GroupTab.plan}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: GroupTripPage.routeName),
        builder: (_) => GroupTripPage(initialTab: tab),
      ),
    );
  }

  // ---------------- Owe card ----------------
  Widget _buildOweCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.chipGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You owe RM 82.30 in 2 groups',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  SizedBox(height: 2),
                  Text('Tap to settle up', style: TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Planning group card ----------------
  Widget _buildPlanGroupCard(_PlanGroup group, {GroupTab tab = GroupTab.plan}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
      onTap: () => _openGroup(context, tab: tab),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      Text(group.timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(group.members, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.navy),
                        ),
                      ),
                      if (group.unread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 22),
                          child: Text(
                            group.unread > 99 ? '99+' : '${group.unread}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: group.tags.map((t) => _buildTag(t)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTag(String label) {
    IconData icon;
    switch (label) {
      case 'Plan Updated':
        icon = Icons.sync_alt;
        break;
      case 'Expenses Updated':
        icon = Icons.account_balance_wallet_outlined;
        break;
      default:
        icon = Icons.how_to_vote_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.chipGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.navy, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _VotingItem {
  final String title, subtitle, date, votes, image;
  const _VotingItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.votes,
    required this.image,
  });
}

class _PlanGroup {
  final String title, members, timeAgo, lastMessage;
  final int unread;
  final List<String> tags;
  const _PlanGroup({
    required this.title,
    required this.members,
    required this.timeAgo,
    required this.lastMessage,
    required this.unread,
    required this.tags,
  });
}