import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/signup_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/account.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/categories/categories_page.dart';
import 'package:abo_glumbo_bbk/pages/home/home_page.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notifications.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/styles/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool? _isGuest;
  int currentIndex = 0;
  @override
  void initState() {
    _isGuest = LocalStoreHelper.getGuestUser();
    if (!(_isGuest ?? false)) {
      context.read<AccountBloc>().add(
        ListenCustomerData(uid: LocalStoreHelper.getUID() ?? ''),
      );
      _initializeNotifications();
    }
    super.initState();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationServices.initializeNotifications();
      await NotificationServices.initializeFCM();
      await NotificationServices.setupFCMListeners();
      await NotificationServices.checkForInitialMessage();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return StreamBuilder(
      stream: AppServices.listenToCustomerData(LocalStoreHelper.getUID() ?? ''),
      builder: (context, snapshot) {
        final customerData = snapshot.data;
        if (customerData == null) {
          return SignupPage();
        }
        final pages = [
          HomePage(),
          CategoriesPage(),
          AccountPage(customerData: customerData),
        ];
        return Scaffold(
          extendBodyBehindAppBar: true,
          body: pages[currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              if (mounted) setState(() => currentIndex = index);
            },
            height: 70,
            destinations: [
              NavigationDestination(
                icon: SvgPicture.asset(
                  AppIcons.homeNav,
                  colorFilter: ColorFilter.mode(
                    AppColors.grey,
                    BlendMode.srcIn,
                  ),
                ),
                selectedIcon: SvgPicture.asset(
                  AppIcons.homeNav,
                  colorFilter: ColorFilter.mode(
                    AppColors.secondary,
                    BlendMode.srcIn,
                  ),
                ),
                label: locale?.home ?? '',
              ),
              NavigationDestination(
                icon: SvgPicture.asset(
                  AppIcons.categoriesNav,
                  colorFilter: ColorFilter.mode(
                    AppColors.grey,
                    BlendMode.srcIn,
                  ),
                ),
                selectedIcon: SvgPicture.asset(
                  AppIcons.categoriesNav,
                  colorFilter: ColorFilter.mode(
                    AppColors.secondary,
                    BlendMode.srcIn,
                  ),
                ),
                label: locale?.categories ?? '',
              ),
              if (!(_isGuest ?? false))
                NavigationDestination(
                  icon: SvgPicture.asset(
                    AppIcons.myBookingNav,
                    colorFilter: ColorFilter.mode(
                      AppColors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                  selectedIcon: SvgPicture.asset(
                    AppIcons.myBookingNav,
                    colorFilter: ColorFilter.mode(
                      AppColors.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: locale?.myBooking ?? '',
                ),
              NavigationDestination(
                icon: SvgPicture.asset(
                  AppIcons.profileNav,
                  colorFilter: ColorFilter.mode(
                    AppColors.grey,
                    BlendMode.srcIn,
                  ),
                ),
                selectedIcon: SvgPicture.asset(
                  AppIcons.profileNav,
                  colorFilter: ColorFilter.mode(
                    AppColors.secondary,
                    BlendMode.srcIn,
                  ),
                ),
                label: locale?.account ?? '',
              ),
            ],
          ),
        );
      },
    );
  }
}
