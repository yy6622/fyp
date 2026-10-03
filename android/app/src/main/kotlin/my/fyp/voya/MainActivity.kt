package my.fyp.voya

// flutter_stripe's native Payment Sheet needs an AppCompat theme + the
// Support Fragment Manager, which FlutterActivity alone doesn't provide —
// its own setup docs ask for FlutterFragmentActivity instead. See
// lib/services/stripe_service.dart / booking_payment_page.dart.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
