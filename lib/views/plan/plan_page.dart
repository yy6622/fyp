import 'package:flutter/material.dart';

import '../../controllers/group_trip_controller.dart';
import '../../controllers/plan_page_controller.dart';
import '../../models/plan_page_models.dart';
import '../../theme.dart';
import '../group/group_trip_page.dart';
import '../group/new_plan_page.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final PlanPageController controller = PlanPageController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 14),
              _buildTabChips(),
              const SizedBox(height: 20),
              if (controller.planGroups.isEmpty) _buildEmptyState(),
              if (controller.planGroups.isNotEmpty) ...[
              if (controller.showVoting && controller.votingItems.isNotEmpty) ...[
                _buildSectionHeader('Current Voting', showIcon: Icons.how_to_vote_outlined),
                const SizedBox(height: 12),
                controller.selectedTab == PlanTab.voting ? _buildVotingDetailedList() : _buildVotingList(),
                const SizedBox(height: 18),
              ],
              if (controller.showOwe) ...[
                controller.selectedTab == PlanTab.expenses ? _buildExpensesTotalCard() : _buildOweCard(),
                const SizedBox(height: 20),
              ],
              if (controller.showGroups) ...[
                _buildSectionHeader(
                  controller.selectedTab == PlanTab.expenses ? 'Group Expenses' : 'Planning',
                  showIcon: controller.selectedTab == PlanTab.expenses
                      ? Icons.account_balance_wallet_outlined
                      : Icons.sync_alt,
                ),
                const SizedBox(height: 12),
                if (controller.selectedTab == PlanTab.expenses)
                  ...controller.planGroups.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildExpenseGroupCard(g),
                      ))
                else
                  ...controller.planGroups.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildPlanGroupCard(g, tab: GroupTab.plan),
                      )),
              ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textGrey),
          const SizedBox(height: 12),
          const Text('No trips yet', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Start planning your first trip with friends', style: TextStyle(color: AppColors.textGrey, fontSize: 11.5)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewPlanPage())),
            icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
            label: const Text('New Plan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
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
          final selected = tab == controller.selectedTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => controller.setSelectedTab(tab),
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
        itemCount: controller.votingItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildVotingCard(controller.votingItems[index]),
      ),
    );
  }

  Widget _buildVotingCard(VotingItem item) {
    return GestureDetector(
      onTap: () => _openGroup(context, item.tripId, tab: GroupTab.vote),
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

  // ---------------- Detailed voting list (Voting tab only) ----------------
  // The "All" tab's horizontal image cards are a compact teaser; selecting
  // Voting specifically should show the poll status clearly, not just repeat
  // the same compact preview.
  Widget _buildVotingDetailedList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: controller.votingItems
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildVotingDetailedCard(item),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildVotingDetailedCard(VotingItem item) {
    return GestureDetector(
      onTap: () => _openGroup(context, item.tripId, tab: GroupTab.vote),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(item.image, width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Text(item.date, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.chipGrey,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.votes, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy)),
                      Text(item.leadingOption, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
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

  void _openGroup(BuildContext context, String tripId, {GroupTab tab = GroupTab.plan}) {
    if (tripId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: GroupTripPage.routeName),
        builder: (_) => GroupTripPage(tripId: tripId, initialTab: tab),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You owe RM ${controller.totalYouOwe.toStringAsFixed(2)} in ${controller.groupsWithBalance} group${controller.groupsWithBalance == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  const Text('Tap Expenses below to settle up', style: TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
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

  // ---------------- Expenses total (Expenses tab only) ----------------
  // Unlike the "All" tab's tap-to-settle notification banner, this is a
  // direct stat: the total figure up front, not wrapped in a message.
  Widget _buildExpensesTotalCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total You Owe', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${controller.totalYouOwe.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text('Across ${controller.groupsWithBalance} groups', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text('Settle Up', style: TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Expense group card (Expenses tab only) ----------------
  // Shows what the group actually owes/spent, not the Plan tab's chat
  // preview — that's the point of a separate filter.
  Widget _buildExpenseGroupCard(PlanGroup group) {
    final settled = group.yourShare <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _openGroup(context, group.tripId, tab: GroupTab.expenses),
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
                        Text(group.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        Text(group.timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(group.members, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total spent', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              Text('RM ${group.totalExpenses.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(settled ? 'Settled' : 'You owe', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                            Text(
                              settled ? 'RM 0.00' : 'RM ${group.yourShare.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold, color: settled ? const Color(0xFF2E8B57) : Colors.redAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 13, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${group.lastExpenseLabel} · RM ${group.lastExpenseAmount.toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.navy),
                            ),
                          ),
                        ],
                      ),
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

  // ---------------- Planning group card ----------------
  Widget _buildPlanGroupCard(PlanGroup group, {GroupTab tab = GroupTab.plan}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
      onTap: () => _openGroup(context, group.tripId, tab: tab),
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
