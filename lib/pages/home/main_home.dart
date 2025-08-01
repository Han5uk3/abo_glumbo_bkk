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
  final int? initialIndex;
  final String? byPassedUid;
  const Home({super.key, this.initialIndex, this.byPassedUid});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool? _isGuest;
  int currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    _isGuest = LocalStoreHelper.getGuestUser();
    if (widget.initialIndex != null && _isGuest == true) {
      currentIndex = widget.initialIndex!;
    }
    if (widget.byPassedUid != null) {
      LocalStoreHelper.putUID(widget.byPassedUid!);
      LocalStoreHelper.putlogoutStatus(false);
    }
    _pages = [
      const HomePage(),
      const CategoriesPage(),
      if (!(_isGuest ?? false)) const BookingsPage(),
    ];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    final uid = LocalStoreHelper.getUID();

    if (_isGuest == true || uid == null || uid.isEmpty) {
      return _buildScaffold(locale, null);
    }

    return StreamBuilder(
      stream: AppServices.listenToCustomerData(widget.byPassedUid ?? uid),
      builder: (context, snapshot) {
        final customerData = snapshot.data;
        return _buildScaffold(locale, customerData);
      },
    );
  }

  Widget _buildScaffold(AppLocalizations? locale, dynamic customerData) {
    Widget getCurrentPage() {
      final accountIndex = (_isGuest ?? false) ? 2 : 3;

      if (currentIndex == accountIndex) {
        return AccountPage(customerData: customerData);
      }
      return _pages[currentIndex];
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex == 0) {
          AlertDialog(
            title: Text(locale?.exitAppTitle ?? 'Exit App'),
            content: Text(
              locale?.exitAppMessage ??
                  'Are you sure you want to exit the app?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(locale?.cancel ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(locale?.exit ?? 'Exit'),
              ),
            ],
          );
        } else {
          setState(() {
            currentIndex = 0;
          });
        }
      },
      child: Scaffold(
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
                colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
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
                colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
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
                colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
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
      ),
    );
  }
}
