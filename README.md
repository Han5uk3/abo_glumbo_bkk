# Abo Glumbo (Customer App)

The official customer application for the Abo Glumbo service platform. This Flutter-based mobile app allows users to easily discover, book, and manage various home and professional services.

## 🚀 Features

- **Service Discovery**: Browse a wide range of service categories and find the right professional for the job.
- **Easy Booking**: Seamless booking process with date/time selection and location pinning.
- **Real-time Tracking**: Track the status of your bookings and the location of assigned technicians.
- **Secure Payments**: Integrated payment gateways (Telr) for safe and convenient transactions.
- **In-App Chat**: Communicate directly with assigned technicians for coordination.
- **Warranty Management**: View and manage warranties for completed services.
- **Multi-Language Support**: Fully localized for **English** and **Arabic** users.
- **Account Management**: Manage profile details, saved addresses, and booking history.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: [Flutter Bloc](https://pub.dev/packages/flutter_bloc)
- **Local Storage**: [Hive](https://pub.dev/packages/hive)
- **Networking**: [Dio](https://pub.dev/packages/dio)
- **Maps**: [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage, Messaging)
- **Payments**: Telr

## 📋 Prerequisites

- **Flutter SDK**: Version `^3.8.1`
- **Dart SDK**: Compatible with Flutter version
- **CocoaPods**: For iOS dependencies (Mac only)
- **Android Studio / VS Code**: Recommended IDEs

## ⚙️ Installation

1.  **Clone the repository:**

    ```bash
    git clone <repository-url>
    cd abo-glumbo-bbk
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Setup Firebase:**

    - Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are placed in their respective directories (`android/app` and `ios/Runner`).

4.  **API Keys:**
    - Configure Google Maps API keys in `AndroidManifest.xml` and `AppDelegate.swift`.

## 📱 Running the Application

To run the app on a connected device or emulator:

```bash
flutter run
```

### Build for Production

- **Android APK:**

  ```bash
  flutter build apk --release
  ```

- **Android App Bundle:**

  ```bash
  flutter build appbundle --release
  ```

- **iOS (Mac only):**
  ```bash
  flutter build ios --release
  ```

## 📂 Project Structure

```
abo-glumbo-bbk/
├── android/            # Android native code
├── assets/             # Images, SVGs, icons, and map styles
├── ios/                # iOS native code
├── lib/                # Main Flutter application code
│   ├── apis/           # API providers
│   ├── common_widgets/ # Reusable UI components
│   ├── helpers/        # Utility functions
│   ├── l10n/           # Localization files
│   ├── models/         # Data models
│   ├── pages/          # Application screens (Home, Bookings, etc.)
│   ├── services/       # App services (Auth, Location, etc.)
│   ├── sheets/         # Bottom sheets
│   ├── styles/         # App theming
│   └── main.dart       # Application entry point
├── pubspec.yaml        # Flutter dependencies and configuration
└── README.md           # Project documentation
```

## 🤝 Contributing

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/new-feature`).
3.  Commit your changes (`git commit -m 'Add new feature'`).
4.  Push to the branch (`git push origin feature/new-feature`).
5.  Open a Pull Request.
