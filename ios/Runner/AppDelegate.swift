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
    
    // Read API key from .env file
    if let envPath = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil),
       let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) {
        let lines = envContent.components(separatedBy: .newlines)
        for line in lines {
            if line.starts(with: "GOOGLE_MAPS_API_KEY=") {
                let key = line.replacingOccurrences(of: "GOOGLE_MAPS_API_KEY=", with: "")
                GMSServices.provideAPIKey(key)
                break
            }
        }
    }

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}