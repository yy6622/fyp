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

  // Real text search over the signed-in user's own trips — matched
  // against the trip's real name/destination (same fields PlanGroup
  // already shows), not a decorative box that did nothing. Case-
  // insensitive, applied in [planGroups] itself so every downstream
  // view ([activePlanGroups]/[pastPlanGroups]) picks it up for free.
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

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
  /// still visible inside that trip's own Vote tab). Same for a poll past
  /// its own deadline ([Vote.isClosed]) — it no longer needs anyone's
  /// vote, so it's just as done as one the person already voted on; the
  /// Vote tab itself still shows it, greyed out with "Voting closed".
  List<VotingItem> get votingItems {
    final items = <VotingItem>[];
    for (final trip in _trips) {
      final votes = _votesByTrip[trip.id] ?? const [];
      final memberCount = trip.memberIds.isEmpty ? 1 : trip.memberIds.length;
      for (final v in votes) {
        final alreadyVoted = v.options.any((o) => o.votedBy.contains(_uid));
        if (alreadyVoted || v.isClosed) continue;
        final leading = v.leading;
        items.add(VotingItem(
          title: trip.name,
          subtitle: v.title,
          // The short "Oct 2026" form, not the full dateRangeLabel — that
          // one's "23 Sep 2026 - 27 Sep 2026  ·  5 days 4 nights" is far
          // too long for the card's corner badge and spilled out of it.
          date: trip.shortDateLabel,
          votes: '${v.totalVoters}/$memberCount voted',
          image: trip.coverImage,
          progress: v.totalVoters / memberCount,
          leadingOption: leading == null || leading.votedBy.isEmpty
              ? 'No votes yet'
              : '${leading.label} is leading with ${leading.votedBy.length} votes',
          tripId: trip.id,
          voteId: v.id,
          voterUids: v.voterUids,
        ));
      }
    }
    return items;
  }

  List<PlanGroup> get planGroups {
    final q = _searchQuery.trim().toLowerCase();
    final trips = q.isEmpty
        ? _trips
        : _trips.where((t) => t.name.toLowerCase().contains(q) || t.destination.toLowerCase().contains(q)).toList();
    return trips.map((trip) {
      final expenses = _expensesByTrip[trip.id] ?? const [];
      final votes = _votesByTrip[trip.id] ?? const [];
      final totalExpenses = expenses.fold(0.0, (s, e) => s + e.amount);
      final yourShare = expenses.fold(
          0.0, (s, e) => s + e.participants.where((p) => p.uid == _uid && !p.paid).fold(0.0, (s2, p) => s2 + p.share));
      // Each tag is a live, "needs your attention right now" state, not a
      // once-true-forever label — see Trip.planUnseenFor/expensesUnseenFor
      // (an edit someone else made that this member hasn't opened that tab
      // to see since) and the same "active + not yet voted" check
      // votingItems above uses for a poll. A tag disappears the moment its
      // condition stops holding (the member opens the tab, votes, or the
      // poll closes) — it's fine, and expected, for a card to show no tags
      // at all once everything's been seen/voted.
      final hasActiveUnvotedPoll =
          votes.any((v) => !v.isClosed && !v.options.any((o) => o.votedBy.contains(_uid)));
      final tags = <String>[
        if (trip.planUnseenFor(_uid)) 'Plan Updated',
        if (trip.expensesUnseenFor(_uid)) 'Expenses Updated',
        if (hasActiveUnvotedPoll) 'Poll Ongoing',
      ];
      return PlanGroup(
        title: trip.name,
        members: '${trip.memberIds.length} member${trip.memberIds.length == 1 ? '' : 's'}',
        timeAgo: trip.createdAt == null ? 'Just now' : formatTimeAgo(trip.createdAt!),
        lastMessage: '${trip.destination} · ${trip.dateRangeLabel}',
        unread: 0,
        tags: tags,
        totalExpenses: totalExpenses,
        yourShare: yourShare,
        lastExpenseLabel: expenses.isEmpty ? '' : expenseLabel(expenses.first),
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
