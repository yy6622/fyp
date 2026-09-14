import 'package:flutter/material.dart';

/// Filter chip shown at the top of the Plan tab.
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
  /// Fraction (0..1) of the group that has voted so far — drives the
  /// progress bar on the detailed Voting-tab card.
  final double progress;
  /// e.g. "L Hotel is leading with 4 votes" — shown only on the detailed
  /// Voting-tab card, not the compact "All" preview.
  final String leadingOption;
  /// Which trip/vote this card opens — set when built from real Firestore
  /// data so tapping it can jump straight to that trip's Vote tab.
  final String tripId;
  final String voteId;
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
  });
}

class PlanGroup {
  final String title, members, timeAgo, lastMessage;
  final int unread;
  final List<String> tags;
  /// Expense-specific figures, used only by the Expenses-tab card.
  final double totalExpenses;
  final double yourShare;
  final String lastExpenseLabel;
  final double lastExpenseAmount;
  /// The real Firestore trip id this card represents.
  final String tripId;
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
  });
}
