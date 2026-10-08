import 'package:flutter/material.dart';

import '../../controllers/booking_details_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import '../shared/member_select_section.dart';
import '../shared/nice_dialog.dart';
import '../shared/nice_pickers.dart';
import '../shared/phone_input_field.dart';
import 'booking_payment_page.dart';

// ---------------------------------------------------------------------
// Guest details — step 1 of the hotel checkout flow (Guest Details ->
// Payment), mirroring Insurance's own two-step purchase flow the same way
// [FlightPassengerDetailsPage] does for flights. Collects what a real
// hotel booking actually needs (full name, email, phone, a passport/ID
// number, optional special requests) plus the room count and stay dates
// — instead of just a guest name. Reached from [BookingBar] for a 'hotel'
// booking.
// ---------------------------------------------------------------------
class HotelGuestDetailsPage extends StatefulWidget {
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

  const HotelGuestDetailsPage({
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
  State<HotelGuestDetailsPage> createState() => _HotelGuestDetailsPageState();
}

class _HotelGuestDetailsPageState extends State<HotelGuestDetailsPage> {
  late final HotelGuestDetailsController controller = HotelGuestDetailsController();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _requestsCtrl = TextEditingController();
  final TextEditingController _checkInCtrl = TextEditingController();
  final TextEditingController _checkOutCtrl = TextEditingController();

  // Who this stay is for, within the trip — see MemberSelectSection and
  // FlightPassengerDetailsPage's equivalent fields.
  Trip? _trip;
  Set<String> _forMemberUids = {};

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
  }

  @override
  void dispose() {
    controller.dispose();
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _idCtrl, _requestsCtrl, _checkInCtrl, _checkOutCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStayDates() async {
    final now = DateTime.now();
    final range = await showVoyaDateRangePicker(
      context: context,
      initialStart: controller.checkIn,
      initialEnd: controller.checkOut,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      title: 'Check-in & Check-out',
    );
    if (range != null) {
      controller.setDates(range.start, range.end);
      setState(() {
        _checkInCtrl.text = formatLongDate(range.start);
        _checkOutCtrl.text = formatLongDate(range.end);
      });
    }
  }

  void _continue() {
    controller.setFullName(_nameCtrl.text);
    controller.setEmail(_emailCtrl.text);
    controller.setPhone(_phoneCtrl.text);
    controller.setIdNumber(_idCtrl.text);
    controller.setSpecialRequests(_requestsCtrl.text);
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
        bookingType: 'hotel',
        bookingTitle: widget.bookingTitle,
        bookingSubtitle: widget.bookingSubtitle,
        refId: widget.refId,
        tripId: widget.tripId,
        quantity: controller.rooms,
        guestName: controller.fullName.trim(),
        guestEmail: controller.email.trim(),
        guestPhone: controller.phone.trim(),
        guestIdNumber: controller.idNumber.trim(),
        specialRequests: controller.specialRequests.trim(),
        checkIn: controller.checkIn,
        checkOut: controller.checkOut,
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
        title: const Text('Guest Details', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
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
                        const Text('Stay Dates & Rooms', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: niceDialogField(_checkInCtrl, 'Check-in', icon: Icons.login, readOnly: true, onTap: _pickStayDates),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: niceDialogField(_checkOutCtrl, 'Check-out', icon: Icons.logout, readOnly: true, onTap: _pickStayDates),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Rooms', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            _roomsStepper(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFDDDDDD)),
                        const SizedBox(height: 12),
                        const Text('Guest Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const Text('Who the stay is booked under, as a real hotel check-in requires.',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        const SizedBox(height: 10),
                        niceDialogField(_nameCtrl, 'Guest Full Name', icon: Icons.person_outline),
                        niceDialogField(_emailCtrl, 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        PhoneInputField(
                          initialValue: _phoneCtrl.text,
                          onChanged: (v) => _phoneCtrl.text = v,
                        ),
                        const SizedBox(height: 12),
                        niceDialogField(_idCtrl, 'Passport / ID Number', icon: Icons.badge_outlined),
                        niceDialogField(_requestsCtrl, 'Special Requests (optional)', icon: Icons.edit_note_outlined, maxLines: 3),
                        if (_trip != null && _trip!.memberIds.length > 1) ...[
                          const SizedBox(height: 8),
                          const Divider(color: Color(0xFFDDDDDD)),
                          const SizedBox(height: 12),
                          MemberSelectSection(
                            memberNames: _trip!.memberNames,
                            selected: _forMemberUids,
                            onChanged: (v) => setState(() => _forMemberUids = v),
                          ),
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

  Widget _roomsStepper() {
    return Row(
      children: [
        _stepperButton(Icons.remove, enabled: controller.rooms > controller.minQuantity, onTap: () => controller.setRooms(controller.rooms - 1)),
        SizedBox(
          width: 32,
          child: Text('${controller.rooms}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ),
        _stepperButton(Icons.add, enabled: controller.rooms < controller.maxQuantity, onTap: () => controller.setRooms(controller.rooms + 1)),
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
}
