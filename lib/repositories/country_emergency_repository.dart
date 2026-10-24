import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/emergency_info.dart';

/// One merged record — [EmergencyNumbers] + [EmbassyInfo] + an optional
/// embassy photo — either read live from the admin-curated
/// `country_emergency_info/{countryKey}` Firestore collection (entered via
/// admin_web/admin/country-emergency.html) or, for any field an admin
/// hasn't filled in yet, backed by the static, already-verified
/// lib/data/emergency_info.dart maps so nothing regresses while the
/// admin-side data is still being migrated.
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

  /// True only when neither Firestore nor the static maps recognise this
  /// destination at all, so [police]/[ambulance]/[fire] are the generic
  /// "112 works almost everywhere" placeholder rather than a real,
  /// country-specific number.
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

  /// True once there's a real, verified mission to show — mirrors the old
  /// `kEmbassyInfoByCountry[key] == null` check EmbassyPage used to make
  /// directly against the static map.
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
      // An admin has entered something for this country, so it's no
      // longer the generic "we don't recognise this destination" state
      // even if some individual fields still fall back to the statics.
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

/// Reads [CountryEmergencyInfo] for a trip's destination, Firestore-first
/// with the static maps as a safety net — see class doc above.
class CountryEmergencyRepository {
  CountryEmergencyRepository._();
  static final CountryEmergencyRepository instance = CountryEmergencyRepository._();

  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('country_emergency_info');

  Future<CountryEmergencyInfo> forDestination(String destination) async {
    final key = destination.trim().toLowerCase();
    if (key.isEmpty) return CountryEmergencyInfo.fromStatic(key);
    try {
      final snap = await _col.doc(key).get();
      final data = snap.data();
      if (snap.exists && data != null) {
        return CountryEmergencyInfo._fromDoc(data, key);
      }
    } catch (_) {
      // Offline, or a permission hiccup — fall through to the static data
      // below rather than leaving the page blank.
    }
    return CountryEmergencyInfo.fromStatic(key);
  }

  /// Reads the embassy/consulate on file for a (destination, home-country)
  /// pair — see [EmbassyRecord]. Firestore-first
  /// (`country_emergency_info/{destinationKey}/embassies/{homeCountryKey}`,
  /// entered via admin/country-emergency-form.html), falling back to the
  /// static [kEmbassyInfoByCountry] map ONLY when [homeCountry] is
  /// Malaysia — that's the only pre-verified static data this app shipped
  /// with. Any other pair with nothing on file in Firestore gets null,
  /// never a guessed answer — see [EmbassyPage]'s "not available" state.
  Future<EmbassyRecord?> embassyFor(String destination, String homeCountry) async {
    final destKey = destination.trim().toLowerCase();
    final homeKey = homeCountry.trim().toLowerCase();
    if (destKey.isEmpty || homeKey.isEmpty) return null;
    try {
      final snap = await _col.doc(destKey).collection('embassies').doc(homeKey).get();
      final data = snap.data();
      if (snap.exists && data != null) {
        return EmbassyRecord._fromDoc(data);
      }
    } catch (_) {
      // Offline, or a permission hiccup — fall through to the Malaysia-only
      // static fallback below rather than leaving the page blank.
    }
    if (homeKey == 'malaysia') {
      final info = kEmbassyInfoByCountry[destKey];
      if (info != null) return EmbassyRecord._fromStaticInfo(info);
    }
    return null;
  }
}

/// One (destination, home-country) embassy/consulate record — see
/// [EmbassyPage], the only reader. Deliberately separate from
/// [CountryEmergencyInfo] (which is destination-only, for the generic
/// police/ambulance/fire numbers): an embassy depends on who's asking,
/// not just where they are, so it's keyed on BOTH the trip's destination
/// and the signed-in user's own home country — see
/// [CountryEmergencyRepository.embassyFor].
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

  /// Builds from a `country_emergency_info/{dest}/embassies/{home}` doc —
  /// field names/types mirror exactly what admin_web/js/data.js's
  /// `saveEmbassy` writes (see admin/country-emergency-form.html's save
  /// handler): `missionName`, `address`, `officeLines` (String list),
  /// `emergencyPhone` (always a String from the admin form, written as
  /// "" when left blank — treated as null here), `email`,
  /// `embassyPhotoUrl`.
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

  /// Builds from the static, Malaysia-only [EmbassyInfo] fallback map —
  /// no photo exists for these (they predate the admin photo-upload
  /// feature), so [embassyPhotoUrl] is always empty here.
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
