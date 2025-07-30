import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/account.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bookings_page.dart';
import 'package:abo_glumbo_bbk/pages/categories/categories_page.dart';
import 'package:abo_glumbo_bbk/pages/home/home_page.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/styles/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool? _isGuest;
  int currentIndex = 0;

  // Create stable page instances to prevent recreation
  late final List<Widget> _pages;

  @override
  void initState() {
    _isGuest = LocalStoreHelper.getGuestUser();

    // Initialize pages once to prevent recreation
    _pages = [
      const HomePage(),
      const CategoriesPage(),
      const BookingsPage(),
      // AccountPage will be handled separately since it needs customerData
    ];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return StreamBuilder(
      stream: AppServices.listenToCustomerData(LocalStoreHelper.getUID() ?? ''),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Error fetching customer data: ${snapshot.error}");
        }
        final customerData = snapshot.data;

        // Use stable page instances, only create AccountPage when needed
        Widget getCurrentPage() {
          if (currentIndex == 3) {
            return AccountPage(customerData: customerData);
          }
          return _pages[currentIndex];
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: getCurrentPage(),
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
