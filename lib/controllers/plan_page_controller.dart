import 'dart:async';

import 'package:flutter/material.dart';

import '../models/plan_page_models.dart';
import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';
import '../services/format_utils.dart';

/// Controller for [PlanPage]. Streams every trip the signed-in user belongs
/// to, plus — for each trip — its open votes and expenses, so the "All" /
/// "Voting" / "Expenses" sections can show real, live data instead of a
/// fixed mock list.
class PlanPageController extends ChangeNotifier {
  PlanTab _selectedTab = PlanTab.all;
  PlanTab get selectedTab => _selectedTab;
  void setSelectedTab(PlanTab value) {
    _selectedTab = value;
    notifyListeners();
  }

  bool get showVoting => _selectedTab == PlanTab.all || _selectedTab == PlanTab.voting;

  double get totalYouOwe => planGroups.fold(0.0, (sum, g) => sum + g.yourShare);
  int get groupsWithBalance => planGroups.where((g) => g.yourShare > 0).length;

  // The Expenses tab always shows its total-owed card, even RM 0.00 — it's
  // a direct stat, not a notification. The "All" tab's card is a
  // tap-to-settle notification instead, so it only makes sense to show
  // when there's actually something owed.
  bool get showOwe => _selectedTab == PlanTab.expenses || (_selectedTab == PlanTab.all && totalYouOwe > 0);
  bool get showGroups =>
      _selectedTab == PlanTab.all || _selectedTab == PlanTab.plan || _selectedTab == PlanTab.expenses;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  bool _loading = true;
  bool get loading => _loading;

  List<Trip> _trips = [];
  final Map<String, List<TripVote>> _votesByTrip = {};
  final Map<String, List<TripExpense>> _expensesByTrip = {};
  final Map<String, StreamSubscription> _voteSubs = {};
  final Map<String, StreamSubscription> _expenseSubs = {};
  StreamSubscription<List<Trip>>? _tripsSub;

  PlanPageController() {
    final uid = _uid;
    if (uid.isEmpty) {
      _loading = false;
      return;
    }
    _tripsSub = TripRepository.instance.watchMyTrips(uid).listen((trips) {
      _trips = trips;
      _loading = false;
      _syncSubs(trips.map((t) => t.id).toSet());
      notifyListeners();
    });
  }

  void _syncSubs(Set<String> tripIds) {
    for (final id in tripIds) {
      _voteSubs.putIfAbsent(
        id,
        () => TripRepository.instance.watchVotes(id).listen((votes) {
          _votesByTrip[id] = votes;
          notifyListeners();
        }),
      );
      _expenseSubs.putIfAbsent(
        id,
        () => TripRepository.instance.watchExpenses(id).listen((expenses) {
          _expensesByTrip[id] = expenses;
          notifyListeners();
        }),
      );
    }
    for (final id in _voteSubs.keys.toList()) {
      if (!tripIds.contains(id)) {
        _voteSubs.remove(id)?.cancel();
        _expenseSubs.remove(id)?.cancel();
        _votesByTrip.remove(id);
        _expensesByTrip.remove(id);
      }
    }
  }

  /// Trips keyed by id, for the active/past split below — rebuilt from
  /// [_trips] on each access, which is fine at the scale of "one user's
  /// own trips."
  Map<String, Trip> get _tripsById => {for (final t in _trips) t.id: t};

  bool isTripInactive(String tripId) => _tripsById[tripId]?.isInactive ?? false;

  /// [planGroups] split by [Trip.isInactive] — the Plan tab shows
  /// [activePlanGroups] up front and folds [pastPlanGroups] into a
  /// collapsed "Past Plans" section.
  List<PlanGroup> get activePlanGroups => planGroups.where((g) => !isTripInactive(g.tripId)).toList();
  List<PlanGroup> get pastPlanGroups => planGroups.where((g) => isTripInactive(g.tripId)).toList();

  /// [votingItems] split the same way, for the Voting section's own past fold.
  List<VotingItem> get activeVotingItems => votingItems.where((v) => !isTripInactive(v.tripId)).toList();
  List<VotingItem> get pastVotingItems => votingItems.where((v) => isTripInactive(v.tripId)).toList();

  /// Polls the signed-in user hasn't voted on yet, across every trip they
  /// belong to. A poll they've already voted on no longer needs their
  /// attention here — it's left off the Plan Home page entirely (it's
  /// still visible inside that trip's own Vote tab).
  List<VotingItem> get votingItems {
    final items = <VotingItem>[];
    for (final trip in _trips) {
      final votes = _votesByTrip[trip.id] ?? const [];
      final memberCount = trip.memberIds.isEmpty ? 1 : trip.memberIds.length;
      for (final v in votes) {
        final alreadyVoted = v.options.any((o) => o.votedBy.contains(_uid));
        if (alreadyVoted) continue;
        final leading = v.leading;
        items.add(VotingItem(
          title: trip.name,
          subtitle: v.title,
          date: trip.dateRangeLabel,
          votes: '${v.totalVoters}/$memberCount voted',
          image: trip.coverImage,
          progress: v.totalVoters / memberCount,
          leadingOption: leading == null || leading.votedBy.isEmpty
              ? 'No votes yet'
              : '${leading.label} is leading with ${leading.votedBy.length} votes',
          tripId: trip.id,
          voteId: v.id,
        ));
      }
    }
    return items;
  }

  List<PlanGroup> get planGroups {
    return _trips.map((trip) {
      final expenses = _expensesByTrip[trip.id] ?? const [];
      final votes = _votesByTrip[trip.id] ?? const [];
      final totalExpenses = expenses.fold(0.0, (s, e) => s + e.amount);
      final yourShare = expenses.fold(
          0.0, (s, e) => s + e.participants.where((p) => p.uid == _uid && !p.paid).fold(0.0, (s2, p) => s2 + p.share));
      final hasActivities = trip.days.any((d) => d.items.isNotEmpty);
      final tags = <String>[
        if (hasActivities) 'Plan Updated',
        if (expenses.isNotEmpty) 'Expenses Updated',
        if (votes.isNotEmpty) 'Poll Ongoing',
      ];
      return PlanGroup(
        title: trip.name,
        members: '${trip.memberIds.length} member${trip.memberIds.length == 1 ? '' : 's'}',
        timeAgo: trip.createdAt == null ? 'Just now' : formatTimeAgo(trip.createdAt!),
        lastMessage: '${trip.destination} · ${trip.dateRangeLabel}',
        unread: 0,
        tags: tags.isEmpty ? ['Plan Updated'] : tags,
        totalExpenses: totalExpenses,
        yourShare: yourShare,
        lastExpenseLabel: expenses.isEmpty ? '' : expenses.first.title,
        lastExpenseAmount: expenses.isEmpty ? 0 : expenses.first.amount,
        tripId: trip.id,
        coverImage: trip.coverImage,
      );
    }).toList();
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    for (final s in _voteSubs.values) {
      s.cancel();
    }
    for (final s in _expenseSubs.values) {
      s.cancel();
    }
    super.dispose();
  }
}
