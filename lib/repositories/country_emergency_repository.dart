import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/emergency_info.dart';

class CountryEmergencyInfo {
  final String police;
  final String ambulance;
  final String fire;
  final String? missionName;
  final String? address;
  final List<String> officeLines;
  final String? emergencyPhone;
  final String? email;
  final String embassyPhotoUrl;

  final bool isGenericFallback;

  const CountryEmergencyInfo({
    required this.police,
    required this.ambulance,
    required this.fire,
    this.missionName,
    this.address,
    this.officeLines = const [],
    this.emergencyPhone,
    this.email,
    this.embassyPhotoUrl = '',
    this.isGenericFallback = false,
  });

  bool get hasEmbassy => (missionName ?? '').isNotEmpty;

  factory CountryEmergencyInfo.fromStatic(String key) {
    final numbers = kEmergencyNumbersByCountry[key];
    final embassy = kEmbassyInfoByCountry[key];
    return CountryEmergencyInfo(
      police: (numbers ?? kFallbackEmergencyNumbers).police,
      ambulance: (numbers ?? kFallbackEmergencyNumbers).ambulance,
      fire: (numbers ?? kFallbackEmergencyNumbers).fire,
      missionName: embassy?.missionName,
      address: embassy?.address,
      officeLines: embassy?.officeLines ?? const [],
      emergencyPhone: embassy?.emergencyPhone,
      email: embassy?.email,
      isGenericFallback: numbers == null,
    );
  }

  factory CountryEmergencyInfo._fromDoc(Map<String, dynamic> data, String key) {
    final fallback = CountryEmergencyInfo.fromStatic(key);
    final rawLines = data['officeLines'];
    final officeLines = rawLines is List ? rawLines.whereType<String>().toList() : const <String>[];
    return CountryEmergencyInfo(
      police: _nonEmpty(data['police'], fallback.police),
      ambulance: _nonEmpty(data['ambulance'], fallback.ambulance),
      fire: _nonEmpty(data['fire'], fallback.fire),
      missionName: _nonEmptyOrNull(data['missionName'], fallback.missionName),
      address: _nonEmptyOrNull(data['address'], fallback.address),
      officeLines: officeLines.isNotEmpty ? officeLines : fallback.officeLines,
      emergencyPhone: _nonEmptyOrNull(data['emergencyPhone'], fallback.emergencyPhone),
      email: _nonEmptyOrNull(data['email'], fallback.email),
      embassyPhotoUrl: data['embassyPhotoUrl'] is String ? data['embassyPhotoUrl'] as String : '',
      isGenericFallback: false,
    );
  }

  static String _nonEmpty(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static String? _nonEmptyOrNull(dynamic value, String? fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
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
    if (key.isEmpty) return CountryEmergencyInfo.fromStatic(key);
    try {
      final snap = await _col.doc(key).get();
      final data = snap.data();
      if (snap.exists && data != null) {
        return CountryEmergencyInfo._fromDoc(data, key);
      }
    } catch (_) {
    }
    return CountryEmergencyInfo.fromStatic(key);
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
    if (homeKey == 'malaysia') {
      final info = kEmbassyInfoByCountry[destKey];
      if (info != null) return EmbassyRecord._fromStaticInfo(info);
    }
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

  factory EmbassyRecord._fromStaticInfo(EmbassyInfo info) {
    return EmbassyRecord(
      missionName: info.missionName,
      address: info.address,
      officeLines: info.officeLines,
      emergencyPhone: info.emergencyPhone,
      email: info.email,
      embassyPhotoUrl: '',
    );
  }
}
