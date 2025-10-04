# Abo Glumbo (abo_glumbo_bbk)

A Flutter mobile application with Firebase integration. This repository contains the app source, Firebase configuration, assets and platform-specific build files.

## Contents

- `lib/` — Flutter source code and generated Firebase options (`lib/firebase_options.dart`).
- `android/`, `ios/` — platform folders and native build configuration.
- `assets/`, `images/`, `map_styles/`, `svg/` — images, icons and map style assets.

## Quick start

Prerequisites:

- Flutter SDK (stable channel). See https://docs.flutter.dev/get-started/install
- Android SDK / Android Studio for Android builds
- Xcode and CocoaPods (macOS only) for iOS builds

Clone and fetch packages:

```powershell
git clone <repo-url>
cd abo-glumbo-bbk
flutter pub get
```

Run on a connected device or emulator:

```powershell
flutter run
```

Run specific platform/device:

```powershell
flutter devices           # list available devices
flutter run -d <deviceId> # replace <deviceId> with one from the list
```

Build release for Android (AAB):

```powershell
flutter build appbundle --release
```

Build for iOS (macOS required):

```powershell
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

## Firebase configuration

This project already contains Firebase configuration helpers and generated options in `lib/firebase_options.dart`. Platform files are present for Android at `android/app/google-services.json`. If you need to reconfigure or re-generate Firebase options use the FlutterFire CLI:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Notes:

- If you change Firebase projects, make sure to replace platform config files (`google-services.json` for Android and `GoogleService-Info.plist` for iOS) and regenerate `lib/firebase_options.dart`.
- Android signing keys and properties are present in `android/key.properties` and `android/app/upload-key.jks`. Keep signing keys secret and do not commit new private keys to the repo.

## Local setup and environment

- `local.properties` contains your Android SDK path and is typically machine-specific — do not commit it.
- `key.properties` should exist for release signing. If you don't have one, create it and update `android/app/build.gradle.kts` accordingly.

## Testing

Run unit and widget tests with:

```powershell
flutter test
```

## Linting & formatting

Format Dart code:

```powershell
dart format .
```

Analyze (static analysis):

```powershell
flutter analyze
```

## Contributing

Contributions are welcome. Typical workflow:

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Commit changes and push
4. Open a Pull Request describing the change

Please follow existing code style and add tests for new logic where appropriate.

## Troubleshooting

- If you encounter build issues on Android, run `flutter clean` then `flutter pub get` and rebuild.
- For iOS builds, ensure CocoaPods are installed and run `pod install` inside `ios/`.

## License & contact

This repository does not currently include a license file. Add an appropriate `LICENSE` file if you plan to open-source this project.

For questions contact the project owner or open an issue in this repository.
