import 'package:flutter/material.dart';

import '../../repositories/catalog_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/dev_seed_service.dart';
import '../../theme.dart';

/// TEMPORARY debug screen — see dev_seed_service.dart's doc comment for
/// exactly what this writes and what to delete alongside it later.
class DevSeedPage extends StatefulWidget {
  const DevSeedPage({super.key});

  @override
  State<DevSeedPage> createState() => _DevSeedPageState();
}

class _DevSeedPageState extends State<DevSeedPage> {
  bool _busy = false;
  bool? _hasSeed;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final has = await DevSeedService.instance.hasSeedData(uid);
    if (!mounted) return;
    setState(() => _hasSeed = has);
  }

  Future<void> _seed() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _status = 'Seeding...';
    });
    try {
      await CatalogRepository.instance.seedIfEmpty();
      final profile = await UserRepository.instance.fetchProfile(uid);
      final name = (profile?.name.isNotEmpty ?? false) ? profile!.name : 'You';
      await DevSeedService.instance.seedAll(uid: uid, myName: name);
      if (!mounted) return;
      setState(() => _status = 'Done — 1 trip, 2 posts, 2 friends, 2 insurance bookings, 4 favorites created.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _refreshStatus();
    }
  }

  Future<void> _clear() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _status = 'Clearing...';
    });
    try {
      await DevSeedService.instance.clearAll(uid);
      if (!mounted) return;
      setState(() => _status = 'Cleared all test data.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text('Debug: Test Data', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This writes one fake trip (with activities, a vote, expenses and '
              'chat), two community posts, two friends, two insurance bookings, '
              'and a couple of Explore favorites into Firestore under your own '
              'account, purely so there is something to demo. Nothing else is '
              'touched, and Clear removes exactly what Seed created.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            ),
            const SizedBox(height: 20),
            if (_hasSeed == true)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Test data already exists.', style: TextStyle(fontSize: 12.5, color: Colors.orange)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy || _hasSeed == true ? null : _seed,
              child: Text(_busy ? 'Working...' : 'Seed Test Data',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy || _hasSeed == false ? null : _clear,
              child: Text(_busy ? 'Working...' : 'Clear Test Data',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty) Text(_status, style: const TextStyle(fontSize: 12.5, color: AppColors.navy)),
          ],
        ),
      ),
    );
  }
}
