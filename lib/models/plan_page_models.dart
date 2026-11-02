import 'package:flutter/material.dart';

enum PlanTab { all, plan, voting, expenses }

extension PlanTabMeta on PlanTab {
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

class VotingItem {
  final String title, subtitle, date, votes, image;
  final double progress;
  final String leadingOption;
  final String tripId;
  final String voteId;
  final List<String> voterUids;
  const VotingItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.votes,
    required this.image,
    this.progress = 0,
    this.leadingOption = '',
    this.tripId = '',
    this.voteId = '',
    this.voterUids = const [],
  });
}

class PlanGroup {
  final String title, members, timeAgo, lastMessage;
  final int unread;
  final List<String> tags;
  final double totalExpenses;
  final double yourShare;
  final String lastExpenseLabel;
  final double lastExpenseAmount;
  final String tripId;
  final String coverImage;
  final bool pinned;
  const PlanGroup({
    required this.title,
    required this.members,
    required this.timeAgo,
    required this.lastMessage,
    required this.unread,
    required this.tags,
    this.totalExpenses = 0,
    this.yourShare = 0,
    this.lastExpenseLabel = '',
    this.lastExpenseAmount = 0,
    this.tripId = '',
    this.coverImage = '',
    this.pinned = false,
  });
}
