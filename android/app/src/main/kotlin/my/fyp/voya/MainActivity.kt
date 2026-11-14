package my.fyp.voya

import android.os.Bundle
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

// flutter_stripe's native Payment Sheet needs an AppCompat theme + the
// Support Fragment Manager, which FlutterActivity alone doesn't provide —
// its own setup docs ask for FlutterFragmentActivity instead. See
// lib/services/stripe_service.dart / booking_payment_page.dart.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Force Stripe's Payment Sheet (and any other native screen Stripe
        // opens as its own Activity) to always render in English, no
        // matter what language the device itself is set to. Stripe's
        // Android SDK has no in-app "locale" setting of its own -- its
        // card-entry form reads the device's system language directly.
        // This uses Android's official per-app language override
        // (AppCompatDelegate -> the system LocaleManager on Android 13+),
        // which applies to the whole app process -- including Activities
        // started by bundled libraries like Stripe's SDK, not just this
        // one. On older Android versions (pre-13) this may not fully
        // override every screen, since there's no OS-level per-app
        // language setting to fall back on there.
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags("en"))
        super.onCreate(savedInstanceState)
    }
}
