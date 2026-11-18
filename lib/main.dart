import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'config/secrets.dart';
import 'firebase_options.dart';
import 'services/demo_mode_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'views/auth/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NOTE: deliberately NOT calling SystemChrome.setPreferredOrientations()
  // here (and NOT setting android:screenOrientation in the manifest --
  // see the note there). Both call Android's setRequestedOrientation()
  // under the hood, and on this device/theme that throws
  // "IllegalStateException: Only fullscreen activities can request
  // orientation" the moment image_picker's camera OR gallery picker opens
  // -- every picker launch temporarily makes the hosting window
  // non-fullscreen, and Android 8+ forbids a fixed-orientation request on
  // a non-fullscreen window. See _PortraitOnly below for the crash-safe,
  // pure-Flutter way this app stays portrait-only instead.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await DemoModeService.instance.init();
  // Fire-and-forget: push-permission/token setup never blocks the splash
  // screen from showing, and failures inside it are swallowed internally.
  NotificationService.instance.init();
  if (!kIsWeb) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voya',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      ),
      home: const SplashPage(),
      builder: (context, child) => _PortraitOnly(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Keeps the app unusable in landscape WITHOUT ever calling a native
/// orientation-lock API (SystemChrome.setPreferredOrientations or
/// android:screenOrientation both do, and both crash this app the moment
/// image_picker opens a camera/gallery picker -- see main() above). This
/// only reads the current orientation via MediaQuery and swaps in a
/// "please rotate back" screen while the phone is sideways; the device is
/// still physically free to rotate (this can't stop that, and doesn't try
/// to), but the traveller can never actually use/see the app's own layout
/// in landscape, and the moment they rotate back to portrait the real
/// screen reappears exactly as they left it.
class _PortraitOnly extends StatelessWidget {
  final Widget child;
  const _PortraitOnly({required this.child});

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (!isLandscape) return child;
    return ColoredBox(
      color: AppColors.scaffoldBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.screen_rotation_alt_outlined, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Please rotate your device back to portrait',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              const Text(
                'Voya is designed for portrait use only.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
