import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../controllers/bottom_nav_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/itinerary_ai_service.dart';
import '../../services/language_service.dart';
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

  // ---------------------------------------------------------------------
  // Real-time location tracking. MainPage stays mounted for as long as
  // the person is signed in and using the app (it's the IndexedStack
  // host behind every tab), which makes it the right long-lived place to
  // run a background position subscription — started only while their
  // own "Share Location with Group" flag (Privacy and Security) is on,
  // and only re-emitting on a real `distanceFilter`-sized move rather
  // than on a timer. See LocationService.trackPosition.
  // ---------------------------------------------------------------------
  StreamSubscription<AppUser?>? _profileSub;
  StreamSubscription<Position>? _positionSub;
  bool _tracking = false;
  // The Firestore profile doc only re-emits when it actually changes, so a
  // mid-stream failure (GPS toggled off, permission revoked) would
  // otherwise leave tracking stuck off with shareLocation still true in
  // Firestore until something unrelated happened to touch the doc again.
  // Caching what the person *wants* separately from whether it's
  // currently running lets the error handler below retry on its own.
  bool _wantsTracking = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    // Warms CurrencyService's rate table for the whole app session (not
    // just once Explore happens to be opened) — MainPage is mounted for
    // as long as the person is signed in and using the app, same reason
    // it hosts location tracking below.
    unawaited(CurrencyService.instance.ensureRatesLoaded());
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _profileSub = UserRepository.instance.watchProfile(uid).listen((user) {
        // See CurrencyService.lastKnownUserCurrency's doc comment — this
        // is the one long-lived subscription that keeps it current for
        // every screen other than Explore (which tracks its own).
        CurrencyService.instance.lastKnownUserCurrency = user?.currencyCode;
        // Same idea, for LanguageService/TranslatedText — see its doc
        // comment.
        LanguageService.instance.lastKnownLanguageCode = user?.languageCode;
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
      // A denied/disabled service mid-stream ends the subscription on its
      // own. Reset the flag and, as long as sharing is still wanted and
      // this page is still mounted, retry after a short delay instead of
      // leaving tracking silently stuck off.
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
          // The AI Summarise status bar used to live only inside
          // GroupTripPage, so leaving that one trip's page (any of the
          // four tabs below, not just Plan) meant losing sight of a run
          // that was still going in the background — the user asked for
          // it to be visible from anywhere in the app, not just "the chat
          // page". A sibling of the IndexedStack, not inside any one
          // page, is what makes that true regardless of which tab is
          // selected.
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

  // IMPORTANT: don't give this a fixed total `height`. The bar must size
  // itself to its content (icon + optional label + padding) and let the
  // bottom safe-area inset (gesture bar / nav bar) add on *top* of that,
  // otherwise devices with a tall inset (or the label appearing on the
  // selected tab) push the content past a fixed height and Flutter
  // reports a bottom overflow.
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

/// The app-wide counterpart to [AiItineraryStatusBar] (which only shows
/// while that one trip's own group page is open) — sits above the bottom
/// nav on every tab, so a run that's still going (or just finished) stays
/// visible no matter where in the app the person wanders off to. Shows
/// nothing when no trip has an active run. Tapping it opens that trip's
/// group page, where the existing page-local bar (and from there, the
/// full sheet) picks up the exact same run — this bar is just a second,
/// always-reachable way to notice it, not a separate one.
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
                    // The per-trip bar on the group page itself doesn't
                    // need the trip's name (it's obvious which trip you're
                    // looking at); this one can be seen from any tab, so a
                    // bare "AI suggestions are ready" would leave someone
                    // with more than one trip guessing which one. Falls
                    // back to the plain status text while the trip doc
                    // hasn't loaded yet or has no name.
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
