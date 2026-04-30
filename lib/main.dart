import 'package:abo_glumbo_bbk/firebase_options.dart';
import 'package:abo_glumbo_bbk/pages/splash%20screen/splash_screen.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/providers.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String hiveBoxName = 'myBox';
GlobalKey<NavigatorState>? navigatorKey = GlobalKey();

// Track if persistence has been set
bool _persistenceEnabled = false;

Future<void> _initializeFirebaseDatabase() async {
  if (!_persistenceEnabled) {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      _persistenceEnabled = true;
      debugPrint('✅ Database persistence enabled');
    } catch (e) {
      debugPrint('⚠️ Persistence already set or error: $e');
      _persistenceEnabled = true;
    }
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('✅ Flutter binding initialized');

    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env file loaded');

    // Initialize Google Maps Renderer for Android
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      try {
        await mapsImplementation.initializeWithRenderer(
          AndroidMapRenderer.latest,
        );
        debugPrint('✅ Google Maps Latest Renderer initialized');
      } catch (e) {
        debugPrint('⚠️ Google Maps Renderer initialization failed: $e');
      }
    }

    // 1. Initialize Firebase FIRST
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ CRITICAL: Firebase initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Firebase is critical - rethrow to show error screen
      throw Exception('Firebase Init Error: $e');
    }

    // 2. Set database persistence (non-critical, can fail gracefully)
    try {
      await _initializeFirebaseDatabase();
    } catch (e) {
      debugPrint('⚠️ Database persistence setup failed (non-critical): $e');
      // Continue anyway - app can work without persistence
    }

    // 3. Set background message handler
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('✅ Background message handler set');
    } catch (e) {
      debugPrint('⚠️ Background message handler setup failed: $e');
      // Continue anyway
    }

    // 4. Initialize Hive
    try {
      await Hive.initFlutter();

      try {
        await Hive.openBox(hiveBoxName);
      } catch (e) {
        debugPrint('⚠️ Hive box corrupted or failed to open: $e. Deleting and reopening...');
        await Hive.deleteBoxFromDisk(hiveBoxName);
        await Hive.openBox(hiveBoxName);
      }
      debugPrint('✅ Hive initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ CRITICAL: Hive initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Hive is critical for app state - rethrow
      throw Exception('Hive Init Error: $e');
    }

    // 6. System UI setup (with One UI 8 fix)
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
      debugPrint('✅ System UI configured (One UI 8 compatible)');
    } catch (e) {
      debugPrint('⚠️ System UI setup failed (non-critical): $e');
      // Continue anyway
    }

    debugPrint('🚀 App initialization complete - launching app');
    runApp(MyApp(navigatorKey: navigatorKey));
  } catch (e, stackTrace) {
    debugPrint('❌ FATAL: App initialization failed completely: $e');
    debugPrint('Stack trace: $stackTrace');

    // Show error screen instead of white screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'App Initialization Failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $e\n\nStack trace preview:\n${stackTrace.toString().split('\n').take(3).join('\n')}',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Please reinstall the app or contact support.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  static Box box = Hive.box(hiveBoxName);
  final GlobalKey<NavigatorState>? navigatorKey;
  const MyApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers,
      child: BlocListener<AccountBloc, AccountState>(
        listener: (context, state) {},
        child: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Abo Glumbo - Customer',
              locale: state.locale,
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('ar')],
              localeResolutionCallback: (locale, supportedLocales) {
                if (supportedLocales.any(
                  (supported) =>
                      supported.languageCode == state.locale.languageCode,
                )) {
                  return state.locale;
                }
                return supportedLocales.first;
              },

              builder: (context, child) {
                final mq = MediaQuery.of(context);
                final bottom = mq.padding.bottom;

                // Samsung OneUI gesture nav bug → returns 0 bottom inset
                final fixedBottom = bottom == 0 ? 16.0 : bottom;

                return MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(bottom: fixedBottom),
                  ),
                  child: Directionality(
                    textDirection: state.locale.languageCode == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: child!,
                  ),
                );
              },

              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
                scaffoldBackgroundColor: AppColors.bgBlueTint,
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: AppColors.bgBlueTint,
                  indicatorColor: Colors.transparent,
                  labelTextStyle: WidgetStateTextStyle.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return DMSansFont.textStyle(
                        color: AppColors.darkGrey,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      );
                    }
                    return DMSansFont.textStyle(
                      color: AppColors.grey,
                      fontSize: 8,
                    );
                  }),
                ),
                dialogTheme: DialogThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  titleSpacing: 0,
                  titleTextStyle: DMSansFont.textStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                searchBarTheme: SearchBarThemeData(
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(AppColors.bgBlueTint),
                  textStyle: WidgetStatePropertyAll(
                    DMSansFont.textStyle(color: Colors.black45, fontSize: 12),
                  ),
                  constraints: const BoxConstraints(
                    minHeight: 50,
                    maxHeight: 50,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  side: const WidgetStatePropertyAll(
                    BorderSide(color: Colors.black12, width: 1),
                  ),
                ),
                bottomSheetTheme: BottomSheetThemeData(
                  backgroundColor: AppColors.bgBlueTint,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                useMaterial3: true,
              ),
              debugShowCheckedModeBanner: false,
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}
