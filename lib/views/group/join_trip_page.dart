import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'group_trip_page.dart';
import 'scan_qr_page.dart';

// ---------------------------------------------------------------------
// Join a trip by typing its invite code — the text form of whatever's
// shown as a QR code on that trip's Group Info page (see InviteQrPage).
// Reached from New Plan's "Join with invite code" tile.
// ---------------------------------------------------------------------
class JoinTripPage extends StatefulWidget {
  const JoinTripPage({super.key});

  @override
  State<JoinTripPage> createState() => _JoinTripPageState();
}

class _JoinTripPageState extends State<JoinTripPage> {
  final _controller = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  Future<void> _join() async {
    final user = AuthService.instance.currentUser;
    if (user == null || _controller.text.trim().isEmpty || _joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final name = user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : (user.email ?? 'Traveller');
      final trip = await TripRepository.instance.joinByInviteCode(_controller.text, uid: user.uid, name: name);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: GroupTripPage.routeName),
          builder: (_) => GroupTripPage(tripId: trip.id),
        ),
        (route) => route.isFirst,
      );
    } on InviteCodeInvalid {
      setState(() => _error = "That doesn't look like a valid invite code.");
    } on InviteTripNotFound {
      setState(() => _error = "Couldn't find a trip for that code — check it and try again.");
    } catch (_) {
      setState(() => _error = 'Something went wrong — please try again.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Join with Invite Code', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the invite code a trip member shared with you — it's the same code shown on that trip's Group Info page.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: 'Enter invite code',
                  hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: TextButton(
                    onPressed: _paste,
                    child: const Text('Paste', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _joining || _controller.text.trim().isEmpty ? null : _join,
                child: _joining
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Join Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ScanQrPage())),
                icon: const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.primary),
                label: const Text('Scan a QR code instead', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
