import 'package:flutter/material.dart';

import '../../data/country_codes.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Reusable phone-number field: a tappable country/dial-code chip (e.g.
// "🇲🇾 +60") next to a plain digits TextField, combined into one string
// such as "+60 123456789" via [onChanged]. Drop-in replacement for a plain
// phone TextField/niceDialogField/AuthTextField at any of the app's phone-
// entry points (Account Setting, onboarding, flight/hotel contact details,
// insurance traveller details) — each of those just stores the combined
// string in the same plain `String phone` field it already had, so no
// model changes are needed anywhere this is dropped in.
// ---------------------------------------------------------------------
class PhoneInputField extends StatefulWidget {
  /// Previously stored value, e.g. "+60 123456789", "0123456789" (no code
  /// — assumed local to [kDefaultDialCode]), or empty.
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String label;
  final bool autofocus;

  const PhoneInputField({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.label = 'Phone Number',
    this.autofocus = false,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late CountryDialCode _selected;
  late final TextEditingController _numberCtrl;

  @override
  void initState() {
    super.initState();
    final raw = (widget.initialValue ?? '').trim();
    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      final match = matchDialCodePrefix(digits);
      if (match != null) {
        _selected = match;
        _numberCtrl = TextEditingController(text: digits.substring(match.dialCode.length).trim());
      } else {
        _selected = kDefaultDialCode;
        _numberCtrl = TextEditingController(text: digits);
      }
    } else {
      _selected = kDefaultDialCode;
      _numberCtrl = TextEditingController(text: raw);
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final number = _numberCtrl.text.trim();
    widget.onChanged(number.isEmpty ? '' : '+${_selected.dialCode} $number');
  }

  Future<void> _pickCountry() async {
    final picked = await pickCountryDialCode(context, selected: _selected);
    if (picked == null) return;
    setState(() => _selected = picked);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            onTap: _pickCountry,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selected.flag, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 5),
                  Text('+${_selected.dialCode}', style: const TextStyle(fontSize: 13.5, color: Colors.black, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textGrey),
                ],
              ),
            ),
          ),
          Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFFECECEC)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _numberCtrl,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.phone,
                onChanged: (_) => _emit(),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13.5, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet country/dial-code picker, in the same shape as the
/// picker sheets already used for Country/Currency/Language in Account
/// Setting — a title, a search box (the dial-code list is longer than
/// those), and a scrollable list of flag + name + dial code.
Future<CountryDialCode?> pickCountryDialCode(BuildContext context, {CountryDialCode? selected}) {
  return showModalBottomSheet<CountryDialCode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _DialCodePickerSheet(selected: selected),
  );
}

class _DialCodePickerSheet extends StatefulWidget {
  final CountryDialCode? selected;
  const _DialCodePickerSheet({this.selected});

  @override
  State<_DialCodePickerSheet> createState() => _DialCodePickerSheetState();
}

class _DialCodePickerSheetState extends State<_DialCodePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = kCountryDialCodes.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.dialCode.contains(q);
    }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Country / Dial Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search country or code',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textGrey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final isSelected = widget.selected != null && widget.selected!.iso2 == c.iso2;
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 20)),
                    title: Text(c.name, style: const TextStyle(fontSize: 13.5)),
                    trailing: Text('+${c.dialCode}', style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textGrey, fontSize: 12.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
                    onTap: () => Navigator.of(context).pop(c),
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
