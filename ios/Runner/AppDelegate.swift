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
    
    // Read API key from .env file using multiple lookup strategies
    var apiKey: String?
    
    // 1. Try to find the asset key using the root view controller if available
    var envKey = "flutter_assets/.env"
    if let controller = window?.rootViewController as? FlutterViewController {
        envKey = controller.lookupKey(forAsset: ".env")
    }
    
    // 2. Define multiple potential paths to look for the .env file
    let possiblePaths = [
        Bundle.main.path(forResource: envKey, ofType: nil),
        Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets"),
        Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil),
        Bundle.main.bundleURL.appendingPathComponent("Frameworks/App.framework/flutter_assets/.env").path,
        Bundle.main.bundleURL.appendingPathComponent("flutter_assets/.env").path
    ]
    
    for path in possiblePaths {
        if let envPath = path,
           FileManager.default.fileExists(atPath: envPath),
           let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) {
            let lines = envContent.components(separatedBy: .newlines)
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.starts(with: "GOOGLE_MAPS_API_KEY=") {
                    let extracted = trimmedLine.replacingOccurrences(of: "GOOGLE_MAPS_API_KEY=", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty {
                        apiKey = extracted
                        break
                    }
                }
            }
        }
        if apiKey != nil { break }
    }

    if let key = apiKey {
        GMSServices.provideAPIKey(key)
    } else {
        // Critical: If we can't find the key, Google Maps will crash
        print("❌ ERROR: Google Maps API Key not found in any .env location!")
    }

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}