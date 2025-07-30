import 'package:abo_glumbo_bbk/firebase_options.dart';
import 'package:abo_glumbo_bbk/helpers/app_color.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/providers.dart';
import 'package:abo_glumbo_bbk/services/notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

final String hiveBoxName = 'myBox';
GlobalKey<NavigatorState>? navigatorKey = GlobalKey();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationServices.setupFCMListeners();
  await NotificationServices.checkForInitialMessage();

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
    return BlocProvider(
      create: (context) => AccountBloc(),
      child: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          return MultiBlocProvider(
            providers: providers,
            child: MaterialApp(
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
              home: const LoginPage(),
            ),
          );
        },
      ),
    );
  }
}
