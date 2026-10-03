import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../repositories/trip_repository.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// The QR / code half of inviting someone to a trip — reached from Group
// Info's "Invite via QR / Code" menu entry. Scanning this with
// Join → Scan QR code (or typing the code below into Join → Enter code)
// adds the scanner/typer as a real trip member — see
// TripRepository.joinByInviteCode and firestore.rules' isSelfJoin().
//
// Shown as a short code rather than the old fake https://voya.app/join/...
// link — there's no real domain behind this app to serve that from, so
// the link never actually opened anything; a bare code is both honest
// about that and reads less like a dead/broken link.
// ---------------------------------------------------------------------
class InviteQrPage extends StatelessWidget {
  final String tripId;
  final String tripName;
  const InviteQrPage({super.key, required this.tripId, required this.tripName});

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied')));
    }
  }

  /// Splits [code] into 4-character groups with a thin space between
  /// them ("aB3d E9kL mN2p Q7rS") purely for on-screen legibility — the
  /// QR code and the copy button both still use the plain, ungrouped
  /// [code]; [TripRepository.parseInviteCode] also strips any spaces/
  /// dashes back out, so pasting this grouped text still works if
  /// someone copies it by hand instead of using the copy button.
  String _groupedForDisplay(String code) {
    final buffer = StringBuffer();
    for (var i = 0; i < code.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(code.substring(i, i + 4 > code.length ? code.length : i + 4));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final code = TripRepository.instance.inviteCodeFor(tripId);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Invite to Trip', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(tripName,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 6),
            const Text(
              "Anyone who scans this QR code or enters the invite code below joins this trip — no approval needed, so only share it with people you trust.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECECEC)),
              ),
              child: QrImageView(data: code, size: 220, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('INVITE CODE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.chipGrey,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFECECEC)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _groupedForDisplay(code),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _copyCode(context, code),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.copy, size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
