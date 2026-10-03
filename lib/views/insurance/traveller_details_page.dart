import 'package:flutter/material.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../theme.dart';
import '../shared/nice_pickers.dart';
import 'payment_method_page.dart';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ---------------------------------------------------------------------
// Traveller details form
// ---------------------------------------------------------------------
class TravellerDetailsPage extends StatefulWidget {
  final InsurancePlan plan;
  // See [InsurancePlanCard.tripId].
  final String? tripId;
  const TravellerDetailsPage({super.key, required this.plan, this.tripId});

  @override
  State<TravellerDetailsPage> createState() => _TravellerDetailsPageState();
}

class _TravellerDetailsPageState extends State<TravellerDetailsPage> {
  final TravellerDetailsController controller = TravellerDetailsController();

  // Real TextEditingControllers for the four plain-text fields per
  // traveller (Full Name, Passport Number, Email, Phone) — these used to
  // be bare TextFields with no controller at all (see
  // TravellerDetailsController's doc comment), so typing into them never
  // reached TravellerData. _addTraveller/_removeTraveller below keep each
  // list's length in exact lockstep with controller.travellerCount, adding
  // or removing at the same index as the traveller itself (not just
  // trimming from the end) so a mid-list removal doesn't mix up which
  // controller belongs to which remaining traveller.
  final List<TextEditingController> _nameCtrls = [];
  final List<TextEditingController> _passportCtrls = [];
  final List<TextEditingController> _emailCtrls = [];
  final List<TextEditingController> _phoneCtrls = [];

  @override
  void initState() {
    super.initState();
    // Starts with exactly one traveller (TravellerDetailsController's own
    // initial state).
    _nameCtrls.add(TextEditingController());
    _passportCtrls.add(TextEditingController());
    _emailCtrls.add(TextEditingController());
    _phoneCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    controller.dispose();
    for (final c in [..._nameCtrls, ..._passportCtrls, ..._emailCtrls, ..._phoneCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTraveller() {
    final added = controller.addTraveller();
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 6 travellers per booking')),
      );
      return;
    }
    setState(() {
      _nameCtrls.add(TextEditingController());
      _passportCtrls.add(TextEditingController());
      _emailCtrls.add(TextEditingController());
      _phoneCtrls.add(TextEditingController());
    });
  }

  void _removeTraveller(int index) {
    if (controller.travellers.length <= 1) return;
    controller.removeTraveller(index);
    setState(() {
      _nameCtrls.removeAt(index).dispose();
      _passportCtrls.removeAt(index).dispose();
      _emailCtrls.removeAt(index).dispose();
      _phoneCtrls.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Insurance', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Traveller Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        for (int i = 0; i < controller.travellerCount; i++) ...[
                          const SizedBox(height: 18),
                          _travellerFields(i),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, style: BorderStyle.solid),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _addTraveller,
                            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                            label: const Text('Add Traveller', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => PaymentMethodPage(plan: widget.plan, travellerCount: controller.travellerCount, tripId: widget.tripId)),
                  ),
                  child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _travellerFields(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Traveller ${index + 1}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(width: 6),
            const Text('(Adult)', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const Spacer(),
            if (index > 0)
              GestureDetector(
                onTap: () => _removeTraveller(index),
                child: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _field(_nameCtrls[index], 'Full Name (as in passport)', onChanged: (v) => controller.setName(index, v)),
        const SizedBox(height: 10),
        _pickerField(
          'Date of Birth',
          controller.travellers[index].dob == null ? null : _formatDate(controller.travellers[index].dob!),
          onTap: () => _pickDob(index),
        ),
        const SizedBox(height: 10),
        _pickerField(
          'Nationality',
          controller.travellers[index].nationality,
          onTap: () => _pickNationality(index),
        ),
        const SizedBox(height: 10),
        _field(_passportCtrls[index], 'Passport Number', onChanged: (v) => controller.setPassport(index, v)),
        if (index == 0) ...[
          const SizedBox(height: 10),
          _field(_emailCtrls[index], 'Email', keyboardType: TextInputType.emailAddress, onChanged: (v) => controller.setEmail(index, v)),
          const SizedBox(height: 10),
          _field(_phoneCtrls[index], 'Phone Number', keyboardType: TextInputType.phone, onChanged: (v) => controller.setPhone(index, v)),
        ],
      ],
    );
  }

  // Was a bare TextField with no controller/onChanged at all — see
  // TravellerDetailsController's doc comment for why that silently
  // discarded whatever was typed. Now a real, wired-up text field.
  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? trailing,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13.5, color: Colors.black),
            ),
          ),
          if (trailing != null) Icon(trailing, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

  /// A tappable field that opens a picker (Nationality, Date of Birth)
  /// instead of accepting free text. Shows [value] when set, otherwise
  /// [label] as a placeholder.
  Widget _pickerField(String label, String? value, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: value == null ? AppColors.textGrey : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  Future<void> _pickDob(int index) async {
    final now = DateTime.now();
    final picked = await showVoyaDatePicker(
      context: context,
      initialDate: controller.travellers[index].dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      title: 'Date of Birth',
    );
    if (picked != null) controller.setDob(index, picked);
  }

  Future<void> _pickNationality(int index) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Nationality', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: nationalityOptions.length,
                itemBuilder: (context, i) {
                  final option = nationalityOptions[i];
                  return ListTile(
                    title: Text(option, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
                    trailing: option == controller.travellers[index].nationality
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) controller.setNationality(index, picked);
  }
}
