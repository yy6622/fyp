import 'package:flutter/material.dart';

import '../../controllers/insurance_controller.dart';
import '../../models/insurance_models.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/nice_pickers.dart';
import '../shared/phone_input_field.dart';
import 'payment_method_page.dart';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class TravellerDetailsPage extends StatefulWidget {
  final InsurancePlan plan;
  // See [InsurancePlanCard.tripId].
  final String? tripId;
  // The destination picked on InsuranceQuotePage, for a standalone (no
  // trip) purchase -- see InsurancePlanDetailPage.destination. Passed
  // straight through to PaymentMethodPage, which is what actually records
  // it on the transaction the admin side reads.
  final String? destination;
  // Set when arriving from a quote/compare flow that already collected
  // these on [InsuranceQuotePage] — pre-fills (and skips re-deriving from
  // the trip) traveller count and travel dates instead of asking again.
  final int? initialTravellerCount;
  final DateTime? initialTravelStart;
  final DateTime? initialTravelEnd;
  const TravellerDetailsPage({
    super.key,
    required this.plan,
    this.tripId,
    this.destination,
    this.initialTravellerCount,
    this.initialTravelStart,
    this.initialTravelEnd,
  });

  @override
  State<TravellerDetailsPage> createState() => _TravellerDetailsPageState();
}

class _TravellerDetailsPageState extends State<TravellerDetailsPage> {
  final TravellerDetailsController controller = TravellerDetailsController();

  bool _loadingTrip = false;
  int _phoneFieldVersion = 0;

  final List<TextEditingController> _nameCtrls = [];
  final List<TextEditingController> _passportCtrls = [];
  final List<TextEditingController> _emailCtrls = [];
  final List<TextEditingController> _phoneCtrls = [];

  @override
  void initState() {
    super.initState();
    _nameCtrls.add(TextEditingController());
    _passportCtrls.add(TextEditingController());
    _emailCtrls.add(TextEditingController());
    _phoneCtrls.add(TextEditingController());
    if (widget.initialTravelStart != null && widget.initialTravelEnd != null) {
      // A quote/compare step already fixed the trip dates — use those
      // instead of re-deriving (and possibly disagreeing with them) from
      // the trip record.
      controller.setTravelDates(widget.initialTravelStart!, widget.initialTravelEnd!);
    } else if (widget.tripId != null && widget.tripId!.isNotEmpty) {
      _loadTripDates();
    }
    if (widget.initialTravellerCount != null) {
      // Grow the controller lists directly (no setState: the first build
      // hasn't happened yet, so there's nothing to re-render) to match the
      // traveller count already chosen on the quote step.
      final clamped = widget.initialTravellerCount!
          .clamp(TravellerDetailsController.minTravellers, TravellerDetailsController.maxTravellers);
      controller.setTravellerCount(clamped);
      while (_nameCtrls.length < controller.travellers.length) {
        _nameCtrls.add(TextEditingController());
        _passportCtrls.add(TextEditingController());
        _emailCtrls.add(TextEditingController());
        _phoneCtrls.add(TextEditingController());
      }
      while (_nameCtrls.length > controller.travellers.length) {
        _nameCtrls.removeLast().dispose();
        _passportCtrls.removeLast().dispose();
        _emailCtrls.removeLast().dispose();
        _phoneCtrls.removeLast().dispose();
      }
    }
    _prefillContactFromAccount();
  }

  Future<void> _prefillContactFromAccount() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    AppUser? profile;
    try {
      profile = await UserRepository.instance.fetchProfile(uid);
    } catch (_) {
      return;
    }
    if (!mounted || profile == null) return;
    setState(() {
      if (_emailCtrls[0].text.trim().isEmpty && profile!.email.trim().isNotEmpty) {
        _emailCtrls[0].text = profile.email;
        controller.setEmail(0, profile.email);
      }
      if (_phoneCtrls[0].text.trim().isEmpty && profile!.phone.trim().isNotEmpty) {
        _phoneCtrls[0].text = profile.phone;
        controller.setPhone(0, profile.phone);
        _phoneFieldVersion++;
      }
    });
  }

  Future<void> _loadTripDates() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingTrip = true);
    Trip? trip;
    try {
      trip = await TripRepository.instance.getTrip(widget.tripId!, uid);
    } catch (_) {
      trip = null;
    }
    if (!mounted) return;
    setState(() {
      _loadingTrip = false;
      if (trip?.startDate != null && trip?.endDate != null) {
        controller.setTravelDates(trip!.startDate!, trip.endDate!);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    for (final c in [..._nameCtrls, ..._passportCtrls, ..._emailCtrls, ..._phoneCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setTravellerCount(int target) {
    final clamped = target.clamp(TravellerDetailsController.minTravellers, TravellerDetailsController.maxTravellers);
    if (clamped == controller.travellers.length) return;
    controller.setTravellerCount(clamped);
    setState(() {
      while (_nameCtrls.length < controller.travellers.length) {
        _nameCtrls.add(TextEditingController());
        _passportCtrls.add(TextEditingController());
        _emailCtrls.add(TextEditingController());
        _phoneCtrls.add(TextEditingController());
      }
      while (_nameCtrls.length > controller.travellers.length) {
        _nameCtrls.removeLast().dispose();
        _passportCtrls.removeLast().dispose();
        _emailCtrls.removeLast().dispose();
        _phoneCtrls.removeLast().dispose();
      }
    });
  }

  void _continue() {
    final error = controller.validate(widget.plan);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => PaymentMethodPage(
                plan: widget.plan,
                travellerCount: controller.travellerCount,
                travellers: controller.travellers,
                tripId: widget.tripId,
                destination: widget.destination,
                travelStart: controller.travelStart!,
                travelEnd: controller.travelEnd!,
              )),
    );
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
                        const Text('Travel Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const SizedBox(height: 4),
                        const Text(
                          'A refund can only be requested before this period begins.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 14),
                        if (_loadingTrip)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          )
                        else
                          _travelPeriodField(),
                      ],
                    ),
                  ),
                  if (widget.plan.hasNationalityRestriction) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFFFF8EE), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFCE4BE))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB8740A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This plan is only available to: ${widget.plan.eligibleCountries.join(', ')}.',
                              style: const TextStyle(fontSize: 12, color: AppColors.navy, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Traveller Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            _travellerStepper(),
                          ],
                        ),
                        for (int i = 0; i < controller.travellerCount; i++) ...[
                          const SizedBox(height: 18),
                          _travellerFields(i),
                        ],
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
                  onPressed: _continue,
                  child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _travellerStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(Icons.remove, enabled: controller.travellerCount > TravellerDetailsController.minTravellers, onTap: () => _setTravellerCount(controller.travellerCount - 1)),
        SizedBox(
          width: 28,
          child: Text('${controller.travellerCount}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ),
        _stepperButton(Icons.add, enabled: controller.travellerCount < TravellerDetailsController.maxTravellers, onTap: () => _setTravellerCount(controller.travellerCount + 1)),
      ],
    );
  }

  Widget _stepperButton(IconData icon, {required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? AppColors.primary.withValues(alpha: 0.1) : AppColors.chipGrey),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: enabled ? AppColors.primary : AppColors.textGrey),
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
          ],
        ),
        const SizedBox(height: 10),
        _field(_nameCtrls[index], 'Full Name (as in IC/passport)', onChanged: (v) => controller.setName(index, v)),
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
        // Malaysians buy travel insurance on their IC (MyKad) — only
        // foreigners are asked for a passport number instead.
        _field(
          _passportCtrls[index],
          controller.travellers[index].nationality == 'Malaysian' ? 'IC Number (MyKad)' : 'Passport Number',
          onChanged: (v) => controller.setIdentityNumber(index, v),
        ),
        if (index == 0) ...[
          const SizedBox(height: 10),
          _field(_emailCtrls[index], 'Email', keyboardType: TextInputType.emailAddress, onChanged: (v) => controller.setEmail(index, v)),
          const SizedBox(height: 10),
          PhoneInputField(
            key: ValueKey('phone-$index-$_phoneFieldVersion'),
            initialValue: _phoneCtrls[index].text,
            onChanged: (v) {
              _phoneCtrls[index].text = v;
              controller.setPhone(index, v);
            },
          ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? trailing,
    TextInputType? keyboardType,
    bool required = true,
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
                label: required
                    ? Text.rich(TextSpan(text: label, children: const [
                        TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ]))
                    : null,
                labelText: required ? null : label,
                labelStyle: const TextStyle(fontSize: 13.5, color: AppColors.textGrey),
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

  Widget _pickerField(String label, String? value, {required VoidCallback onTap, bool required = true}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: value != null
                  ? Text(value, style: const TextStyle(fontSize: 13.5, color: Colors.black))
                  : Text.rich(
                      TextSpan(text: label, children: [
                        if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ]),
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textGrey),
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

  Widget _travelPeriodField() {
    final hasDates = controller.travelStart != null && controller.travelEnd != null;
    final label = hasDates
        ? '${_formatDate(controller.travelStart!)} - ${_formatDate(controller.travelEnd!)}'
        : 'Travel Dates';
    final derivedFromTrip = widget.tripId != null && widget.tripId!.isNotEmpty && hasDates;
    if (derivedFromTrip) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textGrey),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black))),
          ],
        ),
      );
    }
    return _pickerField(label, hasDates ? label : null, onTap: _pickTravelDates);
  }

  Future<void> _pickTravelDates() async {
    final now = DateTime.now();
    final picked = await showVoyaDateRangePicker(
      context: context,
      initialStart: controller.travelStart,
      initialEnd: controller.travelEnd,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      title: 'Travel Dates',
    );
    if (picked != null) controller.setTravelDates(picked.start, picked.end);
  }

  Future<void> _pickNationality(int index) async {
    // When the plan restricts eligible nationalities, only offer those —
    // the traveller simply can't select one this plan doesn't cover,
    // rather than finding out only after filling in the rest of the form.
    final options = widget.plan.hasNationalityRestriction ? widget.plan.eligibleCountries : nationalityOptions;
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
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options[i];
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
