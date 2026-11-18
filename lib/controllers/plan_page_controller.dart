import 'dart:async';

import 'package:flutter/material.dart';

import '../models/plan_page_models.dart';
import '../repositories/trip_repository.dart';
import '../services/auth_service.dart';
import '../services/format_utils.dart';

class PlanPageController extends ChangeNotifier {
  PlanTab _selectedTab = PlanTab.all;
  PlanTab get selectedTab => _selectedTab;
  void setSelectedTab(PlanTab value) {
    _selectedTab = value;
    notifyListeners();
  }

  bool get showVoting => _selectedTab == PlanTab.all || _selectedTab == PlanTab.voting;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  double get totalYouOwe => planGroups.fold(0.0, (sum, g) => sum + g.yourShare);
  int get groupsWithBalance => planGroups.where((g) => g.yourShare > 0).length;

  // Only the dedicated Expenses tab shows balance info now — the "All"
  // tab used to surface an owe-teaser too, which the trip list shouldn't
  // be mixed with.
  bool get showOwe => _selectedTab == PlanTab.expenses;
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
      _syncSubs(trips);
      notifyListeners();
    });
  }

  void _syncSubs(List<Trip> trips) {
    final tripIds = trips.map((t) => t.id).toSet();
    for (final trip in trips) {
      if (trip.isInactive) {
        _voteSubs.remove(trip.id)?.cancel();
        _expenseSubs.remove(trip.id)?.cancel();
        if (!_votesByTrip.containsKey(trip.id)) {
          unawaited(TripRepository.instance.watchVotes(trip.id).first.then((votes) {
            _votesByTrip[trip.id] = votes;
            notifyListeners();
          }));
        }
        if (!_expensesByTrip.containsKey(trip.id)) {
          unawaited(TripRepository.instance.watchExpenses(trip.id).first.then((expenses) {
            _expensesByTrip[trip.id] = expenses;
            notifyListeners();
          }));
        }
        continue;
      }
      _voteSubs.putIfAbsent(
        trip.id,
        () => TripRepository.instance.watchVotes(trip.id).listen((votes) {
          _votesByTrip[trip.id] = votes;
          notifyListeners();
        }),
      );
      _expenseSubs.putIfAbsent(
        trip.id,
        () => TripRepository.instance.watchExpenses(trip.id).listen((expenses) {
          _expensesByTrip[trip.id] = expenses;
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

  Map<String, Trip> get _tripsById => {for (final t in _trips) t.id: t};

  bool isTripInactive(String tripId) => _tripsById[tripId]?.isInactive ?? false;

  List<PlanGroup> get activePlanGroups => planGroups.where((g) => !isTripInactive(g.tripId)).toList();
  List<PlanGroup> get pastPlanGroups => planGroups.where((g) => isTripInactive(g.tripId)).toList();

  List<VotingItem> get activeVotingItems => votingItems.where((v) => !isTripInactive(v.tripId)).toList();
  List<VotingItem> get pastVotingItems => votingItems.where((v) => isTripInactive(v.tripId)).toList();

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
        // Last change, not creation time -- lastActivityAt is stamped on
        // every real mutation (plan/expenses/flights/hotels/settings), see
        // Trip.lastActivityAt in trip_repository.dart.
        timeAgo: (trip.lastActivityAt ?? trip.createdAt) == null
            ? 'Just now'
            : formatTimeAgo((trip.lastActivityAt ?? trip.createdAt)!),
        lastMessage: '${trip.destination} · ${trip.dateRangeLabel}',
        unread: trip.unreadCounts[_uid] ?? 0,
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
