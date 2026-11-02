// Shared setup for Voya's integration tests.
//
// The tests run the REAL app code (repositories, controllers, services) on an
// Android emulator, against the Firebase Local Emulator Suite started from
// this project's firebase.json — so the real firestore.rules are enforced and
// nothing touches the live voya-f69f0 database.
//
// Start everything with run_tests.ps1, or by hand:
//   firebase emulators:exec --only auth,firestore,storage "flutter test integration_test"
//
// On an Android emulator the PC is reachable as 10.0.2.2 (the default below).
// On a real phone pass your PC's LAN IP:
//   flutter test integration_test --dart-define=EMULATOR_HOST=192.168.1.20
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:voya/firebase_options.dart';
import 'package:voya/repositories/user_repository.dart';

const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const String testPassword = 'Test@1234';
final String runId = DateTime.now().millisecondsSinceEpoch.toString();

bool _ready = false;

String get projectId => DefaultFirebaseOptions.currentPlatform.projectId;

String get _docsBase =>
    'http://$emulatorHost:8085/v1/projects/$projectId/databases/(default)/documents';

/// Connects Firebase to the local emulators. Must run before any other
/// Firebase call in the test file.
Future<void> initTestEnv() async {
  if (_ready) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8085);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  _ready = true;
}

/// Wipes the emulator's Firestore data and Auth accounts so every test file
/// starts from an empty database.
Future<void> resetEmulators() async {
  await http.delete(Uri.parse(
      'http://$emulatorHost:8085/emulator/v1/projects/$projectId/databases/(default)/documents'));
  await http.delete(Uri.parse('http://$emulatorHost:9099/emulator/v1/projects/$projectId/accounts'));
  await FirebaseAuth.instance.signOut();
}

class TestUser {
  final String uid;
  final String name;
  final String email;
  const TestUser(this.uid, this.name, this.email);
}

/// Registers a traveller the same way SignupController does (Auth account +
/// users/{uid} profile) and leaves them signed in.
Future<TestUser> createTraveller(String name) async {
  await FirebaseAuth.instance.signOut();
  final email = '${name.toLowerCase().replaceAll(' ', '')}.$runId@voya.test';
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: testPassword);
  final uid = cred.user!.uid;
  await UserRepository.instance.createProfile(uid: uid, name: name, email: email);
  return TestUser(uid, name, email);
}

Future<void> signInAs(TestUser user) async {
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance.signInWithEmailAndPassword(email: user.email, password: testPassword);
}

// ---------------------------------------------------------------------------
// Seeding / inspecting data with admin rights. The Firestore emulator lets a
// request with "Authorization: Bearer owner" bypass security rules — used only
// to set up data the app itself is not allowed to create (an admin record, an
// approved partner, a plan) and to look at data after a test.
// ---------------------------------------------------------------------------
Map<String, dynamic> _encode(dynamic v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  if (v is List) return {'arrayValue': {'values': v.map(_encode).toList()}};
  if (v is Map) {
    return {
      'mapValue': {'fields': v.map((k, val) => MapEntry(k.toString(), _encode(val)))}
    };
  }
  throw ArgumentError('Cannot encode $v');
}

dynamic _decode(Map<String, dynamic> v) {
  if (v.containsKey('nullValue')) return null;
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('timestampValue')) return DateTime.parse(v['timestampValue'] as String);
  if (v.containsKey('arrayValue')) {
    final values = (v['arrayValue']['values'] as List?) ?? const [];
    return values.map((e) => _decode(Map<String, dynamic>.from(e as Map))).toList();
  }
  if (v.containsKey('mapValue')) {
    final fields = Map<String, dynamic>.from((v['mapValue']['fields'] as Map?) ?? const {});
    return fields.map((k, val) => MapEntry(k, _decode(Map<String, dynamic>.from(val as Map))));
  }
  return null;
}

/// Writes a document with admin rights, e.g. seedDoc('admins/$uid', {'role': 'admin'}).
Future<void> seedDoc(String path, Map<String, dynamic> data) async {
  final res = await http.patch(
    Uri.parse('$_docsBase/$path'),
    headers: {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'},
    body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _encode(v)))}),
  );
  if (res.statusCode != 200) throw StateError('seedDoc $path failed: ${res.statusCode} ${res.body}');
}

/// Reads a document with admin rights; null when it does not exist.
Future<Map<String, dynamic>?> ownerGet(String path) async {
  final res = await http.get(Uri.parse('$_docsBase/$path'), headers: {'Authorization': 'Bearer owner'});
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) throw StateError('ownerGet $path failed: ${res.statusCode} ${res.body}');
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final fields = Map<String, dynamic>.from((body['fields'] as Map?) ?? const {});
  return fields.map((k, v) => MapEntry(k, _decode(Map<String, dynamic>.from(v as Map))));
}

/// Lists a collection with admin rights (documents' decoded fields, plus 'id').
Future<List<Map<String, dynamic>>> ownerList(String collectionPath) async {
  final res = await http.get(Uri.parse('$_docsBase/$collectionPath?pageSize=300'),
      headers: {'Authorization': 'Bearer owner'});
  if (res.statusCode != 200) throw StateError('ownerList $collectionPath failed: ${res.statusCode}');
  final docs = ((jsonDecode(res.body) as Map<String, dynamic>)['documents'] as List?) ?? const [];
  return docs.map((d) {
    final doc = Map<String, dynamic>.from(d as Map);
    final fields = Map<String, dynamic>.from((doc['fields'] as Map?) ?? const {});
    return {
      'id': (doc['name'] as String).split('/').last,
      ...fields.map((k, v) => MapEntry(k, _decode(Map<String, dynamic>.from(v as Map)))),
    };
  }).toList();
}

/// Out-of-band emails the Auth emulator "sent" (password reset, verification).
Future<List<Map<String, dynamic>>> authEmulatorEmails() async {
  final res = await http.get(Uri.parse('http://$emulatorHost:9099/emulator/v1/projects/$projectId/oobCodes'));
  final codes = ((jsonDecode(res.body) as Map<String, dynamic>)['oobCodes'] as List?) ?? const [];
  return codes.map((c) => Map<String, dynamic>.from(c as Map)).toList();
}

/// Marks an account's email as verified, the way the verifyCode Cloud Function
/// does with the Admin SDK after a correct sign-up code (FR04).
Future<void> markEmailVerified(String uid) async {
  await http.post(
    Uri.parse('http://$emulatorHost:9099/identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:update'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer owner'},
    body: jsonEncode({'localId': uid, 'emailVerified': true}),
  );
  await FirebaseAuth.instance.currentUser?.reload();
}

/// Expects [action] to be refused by firestore.rules.
Future<void> expectDenied(Future<void> Function() action, {String? reason}) async {
  try {
    await action();
  } on FirebaseException catch (e) {
    expect(e.code, 'permission-denied', reason: reason);
    return;
  }
  fail('Expected permission-denied but the write/read succeeded${reason == null ? '' : ' ($reason)'}');
}

/// Pumps frames until [finder] finds something (screens that load data never
/// "settle", so pumpAndSettle cannot be used). Returns the time it took.
Future<Duration> pumpUntil(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 20), Duration step = const Duration(milliseconds: 50)}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return watch.elapsed;
  }
  throw TestFailure('Timed out after ${timeout.inSeconds} s waiting for $finder');
}

/// Gives fire-and-forget writes (notifications, unread badges) time to land.
Future<void> settle([int ms = 800]) => Future<void>.delayed(Duration(milliseconds: ms));
