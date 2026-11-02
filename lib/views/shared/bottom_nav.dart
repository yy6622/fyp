import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../controllers/bottom_nav_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/itinerary_ai_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../explore/explore_page.dart';
import '../group/group_trip_page.dart';
import '../home/home_page.dart';
import '../plan/plan_page.dart';
import '../profile/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final BottomNavController controller = BottomNavController();

  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    PlanPage(),
    ProfilePage(),
  ];

  static const _icons = [
    'assets/images/nav_home.png',
    'assets/images/nav_compass.png',
    'assets/images/nav_plan.png',
    'assets/images/nav_account.png',
  ];
  static const _labels = ['Home', 'Explore', 'Plan', 'Profile'];

  StreamSubscription<AppUser?>? _profileSub;
  StreamSubscription<Position>? _positionSub;
  bool _tracking = false;
  bool _wantsTracking = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    unawaited(CurrencyService.instance.ensureRatesLoaded());
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _profileSub = UserRepository.instance.watchProfile(uid).listen((user) {
        CurrencyService.instance.lastKnownUserCurrency = user?.currencyCode;
        _wantsTracking = user?.shareLocation ?? false;
        if (_wantsTracking && !_tracking) {
          _startTracking(uid);
        } else if (!_wantsTracking && _tracking) {
          _stopTracking();
        }
      });
    }
  }

  void _startTracking(String uid) {
    _retryTimer?.cancel();
    _tracking = true;
    _positionSub = LocationService.instance.trackPosition().listen(
      (position) {
        UserRepository.instance.updateLocation(uid, position.latitude, position.longitude);
      },
      onError: (_) {
        _tracking = false;
        if (_wantsTracking && mounted) {
          _retryTimer = Timer(const Duration(seconds: 30), () {
            if (mounted && _wantsTracking && !_tracking) _startTracking(uid);
          });
        }
      },
      cancelOnError: true,
    );
  }

  void _stopTracking() {
    _tracking = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    controller.dispose();
    _profileSub?.cancel();
    _positionSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: controller.index,
                  children: _pages,
                ),
              ),
              const _GlobalAiItineraryBar(),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(4, (i) => _navItem(i)),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    final selected = controller.index == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.setIndex(index),
        child: Container(
          color: selected ? AppColors.primary : Colors.white,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  selected ? Colors.white : AppColors.primary,
                  BlendMode.srcIn,
                ),
                child: AppImage(_icons[index], width: 22, height: 22),
              ),
              if (selected) ...[
                const SizedBox(height: 3),
                Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalAiItineraryBar extends StatelessWidget {
  const _GlobalAiItineraryBar();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ItineraryAiService.instance,
      builder: (context, _) {
        final active = ItineraryAiService.instance.anyActiveJob;
        if (active == null) return const SizedBox.shrink();
        final job = active.job;
        final running = job.status == AiItineraryStatus.running;
        final statusText = switch (job.status) {
          AiItineraryStatus.running => 'AI is reading your discussion...',
          AiItineraryStatus.ready => 'AI suggestions are ready',
          _ => 'AI Summarise didn\'t finish',
        };
        final uid = AuthService.instance.currentUser?.uid;
        return Material(
          color: AppColors.chipGrey,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => GroupTripPage(tripId: active.tripId))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  if (running)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: uid == null
                        ? Text(statusText, style: const TextStyle(fontSize: 12.5, color: AppColors.navy))
                        : StreamBuilder<Trip?>(
                            stream: TripRepository.instance.watchTrip(active.tripId, uid),
                            builder: (context, snap) {
                              final name = snap.data?.name;
                              final label = (name == null || name.isEmpty) ? statusText : '$name  ·  $statusText';
                              return Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: AppColors.navy),
                              );
                            },
                          ),
                  ),
                  Text(running ? 'Show' : 'View',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
