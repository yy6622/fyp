import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(settings: const InitializationSettings(android: androidInit, iOS: iosInit));
    }

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {

    }

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _registerToken(user.uid);
    });
    final already = FirebaseAuth.instance.currentUser;
    if (already != null) await _registerToken(already.uid);

    messaging.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _saveToken(uid, token);
    });

    if (!kIsWeb) {
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null) return;
        _local.show(
          id: n.hashCode,
          title: n.title,
          body: n.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'condition_alerts',
              'Trip condition alerts',
              channelDescription: 'Weather and traffic alerts for activities starting soon',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });
    }
  }

  Future<void> _registerToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (_) {
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {
    }
  }
}
