import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Force Stripe's Payment Sheet (and any other native screen Stripe
    // presents) to always render in English, no matter what language the
    // device itself is set to. Stripe's iOS SDK has no in-app "locale"
    // setting of its own -- it resolves its bundled, localized strings
    // from the device's preferred-language list. Overriding AppleLanguages
    // here (the standard iOS technique) changes that preference for every
    // bundle loaded in this process, including third-party frameworks like
    // Stripe's -- not just this app's own Flutter-side strings (which are
    // already English everywhere anyway).
    UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
    UserDefaults.standard.synchronize()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
