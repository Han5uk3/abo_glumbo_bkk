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
    GMSServices.provideAPIKey("AIzaSyBQglwauOyBM2wKjobljQUdlkD4ECnSPp4")
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}