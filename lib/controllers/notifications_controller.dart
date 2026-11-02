import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/friends_repository.dart';
import '../repositories/notifications_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

class NotificationsController extends ChangeNotifier {
  List<AppNotification> _items = [];
  List<AppNotification> get items => _items;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<AppNotification>>? _sub;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  NotificationsController() {
    _listen();
  }

  void _listen() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    _error = null;
    _sub?.cancel();
    _sub = NotificationsRepository.instance.watch(uid).listen(
      (list) {
        _items = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = "Couldn't load notifications: $e";
        notifyListeners();
      },
    );
  }

  void retry() {
    _loading = true;
    notifyListeners();
    _listen();
  }

  Future<void> markRead(String id) => NotificationsRepository.instance.markRead(_uid, id);

  Future<void> dismiss(String id) => NotificationsRepository.instance.delete(_uid, id);

  bool _clearingAll = false;
  bool get clearingAll => _clearingAll;

  Future<String?> removeAll() async {
    _clearingAll = true;
    notifyListeners();
    try {
      await NotificationsRepository.instance.deleteAll(_uid);
      return null;
    } catch (e) {
      return 'Could not clear your notifications — please try again.';
    } finally {
      _clearingAll = false;
      notifyListeners();
    }
  }

  Future<String> respondToFriendRequest(AppNotification n, {required bool accept}) async {
    final fromUid = n.data['fromUid'] as String? ?? '';
    final fromName = n.data['fromName'] as String? ?? 'them';
    final uid = _uid;
    final me = await UserRepository.instance.fetchProfile(uid);
    await FriendsRepository.instance.respondToFriendRequest(
      uid: uid,
      fromUid: fromUid,
      fromName: fromName,
      myName: me?.name ?? 'Traveller',
      accept: accept,
    );
    await dismiss(n.id);
    return accept ? 'You and $fromName are now friends' : 'Friend request declined';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
