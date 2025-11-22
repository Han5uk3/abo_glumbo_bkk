import 'package:abo_glumbo_bbk/firebase_options.dart';
import 'package:abo_glumbo_bbk/pages/splash%20screen/splash_screen.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/providers.dart';
import 'package:abo_glumbo_bbk/services/notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase FIRST
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 2. Set database persistence IMMEDIATELY after Firebase init, before ANY database usage
  await _initializeFirebaseDatabase();
  
  // 3. Set background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // 4. Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox(hiveBoxName);
  
  // 5. Initialize notifications (non-blocking for permissions)
  await NotificationServices.initializeNotifications();
  NotificationServices.setupFCMListeners(); // Don't await - let it run async
  NotificationServices.checkForInitialMessage(); // Don't await
  
  // 6. System UI setup
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  
  runApp(MyApp(navigatorKey: navigatorKey));
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
              title: 'Abo Glumbo',
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
                return Directionality(
                  textDirection: state.locale.languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child!,
                );
              },
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
                scaffoldBackgroundColor: AppColors.bgWhite,
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: Colors.white,
                  indicatorColor: Colors.transparent,
                  labelTextStyle: WidgetStateTextStyle.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return GoogleFonts.dmSans(
                        color: AppColors.darkGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      );
                    }
                    return GoogleFonts.dmSans(
                      color: AppColors.grey,
                      fontSize: 10,
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
                  titleTextStyle: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                searchBarTheme: SearchBarThemeData(
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: const WidgetStatePropertyAll(Colors.white),
                  textStyle: WidgetStatePropertyAll(
                    GoogleFonts.dmSans(color: Colors.black45, fontSize: 14),
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
                bottomSheetTheme: const BottomSheetThemeData(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
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