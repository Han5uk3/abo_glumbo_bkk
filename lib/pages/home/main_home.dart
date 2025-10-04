import 'dart:developer';
import 'dart:io';

import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/account.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bookings_page.dart';
import 'package:abo_glumbo_bbk/pages/categories/categories_page.dart';
import 'package:abo_glumbo_bbk/pages/home/home_page.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/biometric_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/styles/app_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          Scaffold(
            body: Center(child: Loader(color: AppColors.primary)),
          );
        }
        final customerData = snapshot.data;
        final isBlocked = customerData?.isBlocked ?? false;
     
        if (isBlocked) {
          LocalStoreHelper.putBlockStatus(true);
        } else {
          LocalStoreHelper.putBlockStatus(false);
        }
        if (LocalStoreHelper.getBlockStatus() == true) {
          return _buildBlockedScaffold();
        }
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
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
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
            ),
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

  _buildBlockedScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.accountBlocked ?? 'Account Blocked',
        ),
        automaticallyImplyLeading: false, // No back button
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 100, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)?.accountBlocked ??
                    'Account Blocked',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.accountBlockedMessage ??
                    'Your account has been temporarily blocked by the administrator for one or more of the following reasons:',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '- ${AppLocalizations.of(context)?.violationOfTermsAndConditions ?? 'Violation of Terms and Conditions'}\n'
                  '- ${AppLocalizations.of(context)?.improperConduct ?? 'Improper Conduct'}\n'
                  '- ${AppLocalizations.of(context)?.fraudOrRelatedActivities ?? 'Fraud or Related Activities'}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.pleaseContactAdmin ??
                    'Please contact the administrator for more information and possible steps to restore your account.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLogoutConfirmationDialog,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)?.logout ?? 'Logout',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exitApp,
                  icon: Icon(Icons.close, color: AppColors.primary),
                  label: Text(
                    AppLocalizations.of(context)?.exitApp ?? 'Exit App',
                    style: TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary.withAlpha(100)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exitApp() {
    exit(0); // Exit the app completely
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.logout ?? 'Logout',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)?.areYouSureYouWantToLogout ??
                'Are you sure you want to logout?',
            style: GoogleFonts.dmSans(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: GoogleFonts.dmSans(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              child: Text(
                AppLocalizations.of(context)?.logout ?? 'Logout',
                style: GoogleFonts.dmSans(
                  color: AppColors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      await LocalStoreHelper.putlogoutStatus(true);
      await LocalStoreHelper.putGuestUser(false);
      try {
        await AppServices.deleteFCMToken();
      } catch (e) {
        debugPrint('❌ Error deleting FCM token: $e');
      }
      if (await BiometricService.isBiometricEnabled() == true) {
        await BiometricService.setBiometricEnabled(false);
        LocalStoreHelper.clearUID();
      } else {
        LocalStoreHelper.clearUID();
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          'Failed to logout. Please try again.',
          context,
          backgroundColor: AppColors.red,
        );
      }
    }
  }
}
