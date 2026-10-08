import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'config/secrets.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'views/auth/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Real Stripe payment sheet (test/sandbox mode) for Flight/Hotel checkout
  // — see lib/services/stripe_service.dart and
  // lib/views/detail/booking_payment_page.dart. Only the *publishable* key
  // is ever set here; it can start a payment but never move money or read
  // anyone else's data (see config/secrets.dart's doc comment on it).
  Stripe.publishableKey = stripePublishableKey;
  await Stripe.instance.applySettings();
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
        // Material 3's default seed color is purple — with no
        // colorScheme set here, every native Material widget (date/time
        // pickers, checkboxes, snackbars, ...) fell back to that purple
        // instead of the app's own navy brand color. Seeding the scheme
        // from AppColors.primary retheme's all of them at once.
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        // Material 3's other default: once content scrolls underneath an
        // AppBar, it raises the bar's elevation and tints it with
        // colorScheme.surfaceTint (derived from the seed color above) —
        // a visible colour shift the instant you scroll, on every AppBar
        // in the app (Plan's tab bar included). Nothing here ever asked
        // for that tint/shadow look (bottom_nav uses a plain top border
        // instead of elevation, same flat style everywhere else), so it's
        // switched off globally rather than page by page.
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      ),
      home: const SplashPage(),
    );
  }
}
