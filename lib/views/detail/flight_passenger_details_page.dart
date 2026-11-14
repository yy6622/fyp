import 'package:flutter/material.dart';

import '../../controllers/booking_details_controller.dart';
import '../../controllers/insurance_controller.dart' show nationalityOptions;
import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import '../shared/nice_pickers.dart';
import '../shared/phone_input_field.dart';
import 'booking_payment_page.dart';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class FlightPassengerDetailsPage extends StatefulWidget {
  final String itemTitle;
  final String itemSubtitle;
  final double unitPrice;
  final String currencyLabel;
  final String unitSuffix;
  final String bookingTitle;
  final String bookingSubtitle;
  final String refId;
  final String tripId;
  final Future<void> Function(BookingConfirmation confirmation)? onPaid;

  const FlightPassengerDetailsPage({
    super.key,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.unitPrice,
    required this.currencyLabel,
    required this.unitSuffix,
    required this.bookingTitle,
    required this.bookingSubtitle,
    this.refId = '',
    this.tripId = '',
    this.onPaid,
  });

  @override
  State<FlightPassengerDetailsPage> createState() => _FlightPassengerDetailsPageState();
}

class _FlightPassengerDetailsPageState extends State<FlightPassengerDetailsPage> {
  final FlightPassengerDetailsController controller = FlightPassengerDetailsController();

  final List<TextEditingController> _nameCtrls = [TextEditingController()];
  final List<TextEditingController> _passportCtrls = [TextEditingController()];
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  Trip? _trip;
  Set<String> _forMemberUids = {};
  int _phoneFieldVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.tripId.isNotEmpty) {
      final uid = AuthService.instance.currentUser?.uid ?? '';
      TripRepository.instance.watchTrip(widget.tripId, uid).first.then((trip) {
        if (!mounted || trip == null) return;
        setState(() {
          _trip = trip;
          _forMemberUids = trip.memberIds.toSet();
        });
      });
    }
    _prefillContactFromAccount();
  }

  /// The booking contact is usually the account holder themselves, so
  /// default email/phone from the signed-in traveller's profile (still
  /// fully editable) instead of leaving them blank.
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
      if (_emailCtrl.text.trim().isEmpty && profile!.email.trim().isNotEmpty) {
        _emailCtrl.text = profile.email;
        controller.setContactEmail(profile.email);
      }
      if (_phoneCtrl.text.trim().isEmpty && profile!.phone.trim().isNotEmpty) {
        _phoneCtrl.text = profile.phone;
        controller.setContactPhone(profile.phone);
        _phoneFieldVersion++;
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    for (final c in [..._nameCtrls, ..._passportCtrls, _emailCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setPassengerCount(int target) {
    final clamped = target.clamp(controller.minQuantity, controller.maxQuantity);
    if (clamped == controller.passengers.length) return;
    controller.setQuantity(clamped);
    setState(() {
      while (_nameCtrls.length < controller.passengers.length) {
        _nameCtrls.add(TextEditingController());
        _passportCtrls.add(TextEditingController());
      }
      while (_nameCtrls.length > controller.passengers.length) {
        _nameCtrls.removeLast().dispose();
        _passportCtrls.removeLast().dispose();
      }
    });
  }

  void _continue() {
    final error = controller.validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingPaymentPage(
        itemTitle: widget.itemTitle,
        itemSubtitle: widget.itemSubtitle,
        unitPrice: widget.unitPrice,
        currencyLabel: widget.currencyLabel,
        unitSuffix: widget.unitSuffix,
        bookingType: 'flight',
        bookingTitle: widget.bookingTitle,
        bookingSubtitle: widget.bookingSubtitle,
        refId: widget.refId,
        tripId: widget.tripId,
        quantity: controller.quantity,
        passengerDetails: controller.passengers,
        contactEmail: controller.contactEmail.trim(),
        contactPhone: controller.contactPhone.trim(),
        forMemberUids: _forMemberUids.toList(),
        onPaid: widget.onPaid,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Passenger Details', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text(widget.bookingTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const SizedBox(height: 2),
                        Text(widget.bookingSubtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Passenger Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            _passengerStepper(),
                          ],
                        ),
                        const Text('One full passenger record per seat, as a real airline booking requires.',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        for (int i = 0; i < controller.passengers.length; i++) ...[
                          const SizedBox(height: 16),
                          _passengerFields(i),
                        ],
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFDDDDDD)),
                        const SizedBox(height: 12),
                        const Text('Contact Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const Text('Used for booking confirmation and any travel updates.',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        const SizedBox(height: 10),
                        niceDialogField(_emailCtrl, 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
                            onTap: null),
                        const SizedBox(height: 12),
                        PhoneInputField(
                          key: ValueKey(_phoneFieldVersion),
                          initialValue: _phoneCtrl.text,
                          onChanged: (v) => _phoneCtrl.text = v,
                        ),
                        const SizedBox(height: 12),
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
                  onPressed: () {
                    controller.setContactEmail(_emailCtrl.text);
                    controller.setContactPhone(_phoneCtrl.text);
                    _continue();
                  },
                  child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passengerStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(Icons.remove, enabled: controller.passengers.length > controller.minQuantity, onTap: () => _setPassengerCount(controller.passengers.length - 1)),
        SizedBox(
          width: 28,
          child: Text('${controller.passengers.length}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ),
        _stepperButton(Icons.add, enabled: controller.passengers.length < controller.maxQuantity, onTap: () => _setPassengerCount(controller.passengers.length + 1)),
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

  Widget _passengerFields(int index) {
    final p = controller.passengers[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Passenger ${index + 1}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        _textField(_nameCtrls[index], 'Full Name (as in passport)', onChanged: (v) => controller.setName(index, v)),
        const SizedBox(height: 10),
        _pickerField(
          'Date of Birth',
          p.dob == null ? null : _formatDate(p.dob!),
          onTap: () => _pickDob(index),
        ),
        const SizedBox(height: 10),
        _pickerField('Nationality', p.nationality, onTap: () => _pickNationality(index)),
        const SizedBox(height: 10),
        _textField(_passportCtrls[index], 'Passport Number', onChanged: (v) => controller.setPassportNumber(index, v)),
        const SizedBox(height: 10),
        _pickerField(
          'Passport Expiry Date',
          p.passportExpiry == null ? null : _formatDate(p.passportExpiry!),
          onTap: () => _pickPassportExpiry(index),
        ),
      ],
    );
  }

  Widget _textField(TextEditingController ctrl, String label, {required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13.5, color: AppColors.textGrey),
          border: InputBorder.none,
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13.5, color: Colors.black),
      ),
    );
  }

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
              child: Text(value ?? label, style: TextStyle(fontSize: 13.5, color: value == null ? AppColors.textGrey : Colors.black)),
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
      initialDate: controller.passengers[index].dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      title: 'Date of Birth',
    );
    if (picked != null) controller.setDob(index, picked);
  }

  Future<void> _pickPassportExpiry(int index) async {
    final now = DateTime.now();
    final picked = await showVoyaDatePicker(
      context: context,
      initialDate: controller.passengers[index].passportExpiry ?? DateTime(now.year + 2, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      title: 'Passport Expiry Date',
    );
    if (picked != null) controller.setPassportExpiry(index, picked);
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
                    trailing: option == controller.passengers[index].nationality ? const Icon(Icons.check, color: AppColors.primary) : null,
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
