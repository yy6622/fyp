import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/profile_controller.dart';
import '../../data/countries.dart';
import '../../data/malaysia_airports.dart';
import '../../data/popular_destinations.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../services/language_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import '../shared/phone_input_field.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Account Setting
// ---------------------------------------------------------------------
class AccountSettingPage extends StatefulWidget {
  const AccountSettingPage({super.key});

  @override
  State<AccountSettingPage> createState() => _AccountSettingPageState();
}

class _AccountSettingPageState extends State<AccountSettingPage> {
  final ProfileController controller = ProfileController();
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final file = await AvatarService.instance.pick(source);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await AvatarService.instance.upload(uid, file);
      await UserRepository.instance.updateProfile(uid, avatarUrl: url);
    } catch (e) {
      // Raw error, not a generic message — need to see whether this is a
      // Storage permission/setup problem or a platform-support problem.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't upload photo: $e")));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _changeCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PickerSheet<Country>(
        title: 'Country / Region',
        items: kCountries,
        labelOf: (c) => c.name,
        trailingOf: (c) => c.currencyCode,
      ),
    );
    if (picked == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, country: picked.name);
  }

  Future<void> _changeCurrency() async {
    final picked = await showModalBottomSheet<CurrencyOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PickerSheet<CurrencyOption>(
        title: 'Currency',
        items: kCurrencies,
        labelOf: (c) => c.code,
        trailingOf: (c) => c.symbol,
      ),
    );
    if (picked == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, currencyCode: picked.code);
  }

  /// Attraction/restaurant/hotel names show translated into whichever
  /// language is picked here (see LanguageService/TranslatedText) — this
  /// row used to just read 'English' with no way to change it at all.
  Future<void> _changeLanguage() async {
    final picked = await showModalBottomSheet<LanguageOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PickerSheet<LanguageOption>(
        title: 'Language',
        items: kSupportedLanguages,
        labelOf: (l) => l.label,
        trailingOf: (l) => l.code,
      ),
    );
    if (picked == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, languageCode: picked.code);
  }

  /// "Kuala Lumpur (KUL)" for a known airport code, or the bare code
  /// itself if it's somehow not in [kMalaysiaAirports] (shouldn't
  /// happen, but a raw code is still a meaningful fallback label).
  String _airportLabel(String iataCode) {
    for (final a in kMalaysiaAirports) {
      if (a.iataCode == iataCode) return '${a.city.split(',').first} (${a.iataCode})';
    }
    return iataCode;
  }

  Future<void> _changeHomeAirport() async {
    final picked = await showModalBottomSheet<MalaysiaAirport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _HomeAirportPickerSheet(),
    );
    if (picked == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, homeAirportCode: picked.iataCode);
  }

  Future<void> _editField({required String label, required String current, required String field}) async {
    final ctrl = TextEditingController(text: current == 'Not set' ? '' : current);
    final result = await showNiceFormDialog(
      context: context,
      title: label,
      headerIcon: Icons.edit_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(ctrl, label, autofocus: true),
      ],
    );
    if (result != true) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final value = ctrl.text.trim();
    await UserRepository.instance.updateProfile(uid, name: field == 'name' ? value : null, phone: field == 'phone' ? value : null);
  }

  Future<void> _editPhone(String current) async {
    String value = current == 'Not set' ? '' : current;
    final result = await showNiceFormDialog(
      context: context,
      title: 'Phone Number',
      headerIcon: Icons.edit_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PhoneInputField(initialValue: value, onChanged: (v) => value = v),
        ),
      ],
    );
    if (result != true) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, phone: value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Account Setting',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final profile = controller.profile;
          final username = profile?.name.isNotEmpty == true ? profile!.name : 'Not set';
          final email = profile?.email ?? (AuthService.instance.currentUser?.email ?? '');
          final phone = (profile?.phone.isNotEmpty ?? false) ? profile!.phone : 'Not set';
          final country = (profile?.country.isNotEmpty ?? false) ? profile!.country : 'Not set';
          final currency = (profile?.currencyCode.isNotEmpty ?? false) ? profile!.currencyCode : 'Not set';
          final homeAirport = _airportLabel((profile?.homeAirportCode.isNotEmpty ?? false) ? profile!.homeAirportCode : kDefaultHomeAirport);
          return ListView(
            children: [
              profileNavRow('Username', username, onTap: () => _editField(label: 'Username', current: username, field: 'name')),
              InkWell(
                onTap: _uploadingAvatar ? null : _changeAvatar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
                  child: Row(
                    children: [
                      const Text('Avatar', style: TextStyle(fontSize: 14, color: Colors.black)),
                      const Spacer(),
                      if (_uploadingAvatar)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      else
                        AppAvatar(
                          imageUrl: profile?.avatarUrl,
                          radius: 18,
                          backgroundColor: const Color(0xFFD9D9D9),
                          iconSize: 18,
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
                    ],
                  ),
                ),
              ),
              profileNavRow('Password', '••••••••'),
              profileNavRow('Email', email),
              profileNavRow('Phone Number', phone, onTap: () => _editPhone(phone)),
              profileNavRow('Language', LanguageService.instance.labelFor(profile?.languageCode ?? ''), onTap: _changeLanguage),
              profileNavRow('Country / Region', country, onTap: _changeCountry),
              profileNavRow('Currency', currency, onTap: _changeCurrency),
              profileNavRow('Home Airport', homeAirport, onTap: _changeHomeAirport),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => showNiceConfirmDialog(
                      context: context,
                      title: 'Delete Account',
                      message: 'This permanently deletes your account and all your trips. This cannot be undone. Are you sure?',
                      confirmLabel: 'Delete',
                      icon: Icons.warning_amber_rounded,
                      destructive: true,
                    ),
                    child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Home Airport's picker sheet — unlike the plain [_PickerSheet] below,
/// this one kicks off an on-demand [LocationService] lookup as soon as
/// it opens and, when that succeeds, puts the nearest airport(s) in
/// their own "NEAR YOU" section above the full list (see
/// `location_service.dart`'s doc comment for why: someone in Penang
/// should be offered PEN, not have to scroll a plain A-Z list looking
/// for it while KUL sits at the top by coincidence of list order).
/// Location failing in any of its ordinary ways (service off,
/// permission declined, no fix within the timeout) just shows a short
/// explanation and falls back to the plain full list — never blocks
/// picking an airport manually.
class _HomeAirportPickerSheet extends StatefulWidget {
  const _HomeAirportPickerSheet();

  @override
  State<_HomeAirportPickerSheet> createState() => _HomeAirportPickerSheetState();
}

class _HomeAirportPickerSheetState extends State<_HomeAirportPickerSheet> {
  LocationLookupResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    final result = await LocationService.instance.suggestNearestAirport();
    if (mounted) setState(() => _result = result);
    if (mounted) setState(() => _loading = false);
  }

  String? get _statusMessage {
    switch (_result?.status) {
      case LocationLookupStatus.serviceDisabled:
        return 'Turn on location services to see airports near you.';
      case LocationLookupStatus.permissionDenied:
        return "Location permission wasn't granted — showing all airports instead.";
      case LocationLookupStatus.permissionDeniedForever:
        return 'Location permission is blocked — enable it in system settings to see nearby airports.';
      case LocationLookupStatus.failed:
        return "Couldn't get your location — showing all airports instead.";
      case LocationLookupStatus.success:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearby = _result?.rankedByDistanceKm?.take(3).toList() ?? const <MapEntry<MalaysiaAirport, double>>[];
    final nearbyCodes = nearby.map((e) => e.key.iataCode).toSet();
    final rest = kMalaysiaAirports.where((a) => !nearbyCodes.contains(a.iataCode)).toList();
    final message = _statusMessage;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Home Airport', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 2),
            const Text('Used as your departure point for flight searches.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  SizedBox(width: 10),
                  Text('Finding airports near you…', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ]),
              )
            else if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(message, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (nearby.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 2),
                      child: Text('NEAR YOU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.4)),
                    ),
                    ...nearby.map((e) => _airportTile(e.key, distanceKm: e.value)),
                    const Divider(height: 20),
                  ],
                  ...rest.map((a) => _airportTile(a)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _airportTile(MalaysiaAirport airport, {double? distanceKm}) {
    return ListTile(
      leading: const Icon(Icons.flight_takeoff, size: 18, color: AppColors.primary),
      title: Text(airport.city.split(',').first, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(airport.name, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(airport.iataCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 12.5)),
          if (distanceKm != null)
            Text('${distanceKm.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
        ],
      ),
      onTap: () => Navigator.of(context).pop(airport),
    );
  }
}

/// A plain scrollable pick-one-from-a-list bottom sheet, shared by the
/// Country/Region and Currency rows above — pops the chosen item.
class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T) trailingOf;
  const _PickerSheet({required this.title, required this.items, required this.labelOf, required this.trailingOf});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ListTile(
                    title: Text(labelOf(item), style: const TextStyle(fontSize: 13.5)),
                    trailing: Text(trailingOf(item), style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
