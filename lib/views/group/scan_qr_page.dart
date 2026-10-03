import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import 'group_trip_page.dart';
import 'join_trip_page.dart';

// ---------------------------------------------------------------------
// Scan a trip's invite QR code (shown on that trip's Group Info page —
// see InviteQrPage) to join it with the camera instead of typing the
// invite code. Reached from New Plan's "Scan QR code" tile.
// ---------------------------------------------------------------------
class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || !mounted) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() {
      _handling = true;
      _error = null;
    });
    await _controller.stop();
    try {
      final name = user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : (user.email ?? 'Traveller');
      final trip = await TripRepository.instance.joinByInviteCode(raw, uid: user.uid, name: name);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: GroupTripPage.routeName),
          builder: (_) => GroupTripPage(tripId: trip.id),
        ),
        (route) => route.isFirst,
      );
    } on InviteCodeInvalid {
      _resumeWithError("That QR code isn't a Voya invite.");
    } on InviteTripNotFound {
      _resumeWithError("Couldn't find that trip — the invite may be old or wrong.");
    } catch (_) {
      _resumeWithError('Something went wrong — please try again.');
    }
  }

  void _resumeWithError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _handling = false;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              child: _ScanFrame(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Column(
              children: [
                if (_handling)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  const Text(
                    "Point your camera at a trip's invite QR code",
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5), textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const JoinTripPage())),
                  icon: const Icon(Icons.keyboard, size: 18, color: Colors.white),
                  label: const Text('Enter code manually instead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The square viewfinder outline over the camera preview — purely
/// decorative (mobile_scanner finds a code anywhere in frame, not just
/// inside this box), so it's wrapped in [IgnorePointer] at the call site.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(20)),
    );
  }
}
