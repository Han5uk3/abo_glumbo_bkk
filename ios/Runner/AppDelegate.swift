import UIKit
import Flutter
import GoogleMaps
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ Firebase is initialized by Flutter in main.dart
    // Removed FirebaseApp.configure() to prevent double initialization crash
    GeneratedPluginRegistrant.register(with: self)
    GMSServices.provideAPIKey("AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}