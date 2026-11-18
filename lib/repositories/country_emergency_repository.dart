import 'package:cloud_firestore/cloud_firestore.dart';

class CountryEmergencyInfo {
  final String? police;
  final String? ambulance;
  final String? fire;
  final String? missionName;
  final String? address;
  final List<String> officeLines;
  final String? emergencyPhone;
  final String? email;
  final String embassyPhotoUrl;

  /// True when Firestore has no doc at all for this country. There is no
  /// hardcoded fallback behind this anymore (removed 2026-11-17, at the
  /// user's request -- a wrong/outdated guess is worse than an honest "we
  /// don't have this yet"), so a null field genuinely means "unknown", not
  /// "falling back to something else".
  final bool isUnavailable;

  const CountryEmergencyInfo({
    this.police,
    this.ambulance,
    this.fire,
    this.missionName,
    this.address,
    this.officeLines = const [],
    this.emergencyPhone,
    this.email,
    this.embassyPhotoUrl = '',
    this.isUnavailable = false,
  });

  bool get hasEmbassy => (missionName ?? '').isNotEmpty;

  const CountryEmergencyInfo.unavailable() : this(isUnavailable: true);

  factory CountryEmergencyInfo._fromDoc(Map<String, dynamic> data) {
    final rawLines = data['officeLines'];
    final officeLines = rawLines is List ? rawLines.whereType<String>().toList() : const <String>[];
    return CountryEmergencyInfo(
      police: _nonEmptyOrNull(data['police']),
      ambulance: _nonEmptyOrNull(data['ambulance']),
      fire: _nonEmptyOrNull(data['fire']),
      missionName: _nonEmptyOrNull(data['missionName']),
      address: _nonEmptyOrNull(data['address']),
      officeLines: officeLines,
      emergencyPhone: _nonEmptyOrNull(data['emergencyPhone']),
      email: _nonEmptyOrNull(data['email']),
      embassyPhotoUrl: data['embassyPhotoUrl'] is String ? data['embassyPhotoUrl'] as String : '',
    );
  }

  static String? _nonEmptyOrNull(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }
}

class CountryEmergencyRepository {
  CountryEmergencyRepository._();
  static final CountryEmergencyRepository instance = CountryEmergencyRepository._();

  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('country_emergency_info');

  String _countryKeyFor(String destination) {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return '';
    final lastComma = trimmed.lastIndexOf(',');
    final country = lastComma == -1 ? trimmed : trimmed.substring(lastComma + 1);
    return country.trim().toLowerCase();
  }

  Future<CountryEmergencyInfo> forDestination(String destination) async {
    final key = _countryKeyFor(destination);
    if (key.isEmpty) return const CountryEmergencyInfo.unavailable();
    try {
      final snap = await _col.doc(key).get();
      final data = snap.data();
      if (snap.exists && data != null) {
        return CountryEmergencyInfo._fromDoc(data);
      }
    } catch (_) {
    }
    return const CountryEmergencyInfo.unavailable();
  }

  Future<EmbassyRecord?> embassyFor(String destination, String homeCountry) async {
    final destKey = _countryKeyFor(destination);
    final homeKey = homeCountry.trim().toLowerCase();
    if (destKey.isEmpty || homeKey.isEmpty) return null;
    try {
      final snap = await _col.doc(destKey).collection('embassies').doc(homeKey).get();
      final data = snap.data();
      if (snap.exists && data != null) {
        return EmbassyRecord._fromDoc(data);
      }
    } catch (_) {
    }
    // No fallback -- Firestore (via the admin console's Embassies tab) is
    // the only source. A null here means the UI shows its own honest "we
    // don't have verified details yet" state instead of guessing.
    return null;
  }
}

class EmbassyRecord {
  final String missionName;
  final String address;
  final List<String> officeLines;
  final String? emergencyPhone;
  final String email;
  final String embassyPhotoUrl;

  const EmbassyRecord({
    required this.missionName,
    required this.address,
    this.officeLines = const [],
    this.emergencyPhone,
    required this.email,
    this.embassyPhotoUrl = '',
  });

  factory EmbassyRecord._fromDoc(Map<String, dynamic> data) {
    final rawLines = data['officeLines'];
    final officeLines = rawLines is List ? rawLines.whereType<String>().toList() : const <String>[];
    final rawPhone = data['emergencyPhone'];
    return EmbassyRecord(
      missionName: (data['missionName'] as String?)?.trim() ?? '',
      address: (data['address'] as String?)?.trim() ?? '',
      officeLines: officeLines,
      emergencyPhone: (rawPhone is String && rawPhone.trim().isNotEmpty) ? rawPhone.trim() : null,
      email: (data['email'] as String?)?.trim() ?? '',
      embassyPhotoUrl: data['embassyPhotoUrl'] is String ? data['embassyPhotoUrl'] as String : '',
    );
  }
}
