import 'dart:io';

import 'package:abo_glumbo_bbk/common_widgets/customNavigationBar.dart';
import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/welcome_modal.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/account.dart';
import 'package:abo_glumbo_bbk/pages/accounts/edit_profile.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bookings_page.dart';
import 'package:abo_glumbo_bbk/pages/home/home_page.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/biometric_service.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/styles/app_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Home extends StatefulWidget {
  final int? initialIndex;
  final String? byPassedUid;
  final bool isNewRegistration;
  const Home({
    super.key,
    this.initialIndex,
    this.byPassedUid,
    this.isNewRegistration = false,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool? _isGuest;
  int currentIndex = 0;
  bool _hasShownWelcome = false;

  String whatsapp = "";
  String phone = "";
  String email = "";
  late final List<Widget> _pages;
  late final Stream<dynamic> _customerStream;

  @override
  void initState() {
    _isGuest = LocalStoreHelper.getGuestUser();
    if (widget.initialIndex != null && _isGuest == true) {
      currentIndex = widget.initialIndex!;
    }
    String? uid;
    if (widget.byPassedUid != null) {
      uid = widget.byPassedUid!;
      LocalStoreHelper.putUID(uid);
      LocalStoreHelper.putlogoutStatus(false);
    } else {
      uid = LocalStoreHelper.getUID();
    }

    _customerStream = AppServices.listenToCustomerData(uid ?? '');

    // Initial pages setup (AccountPage will be added dynamically in build)
    _pages = [const HomePage(), if (!(_isGuest ?? false)) const BookingsPage()];

    super.initState();

    // Initialize notifications after splash screen
    Future.delayed(Duration.zero, () async {
      await NotificationServices.initializeNotifications();
      NotificationServices.setupFCMListeners();
      await NotificationServices.checkForInitialMessage();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  static Future<void> launchEmail(String email) async {
    await launchUrlString("mailto:$email");
  }

  static Future<void> launchWhatsApp(String phoneNumber) async {
    final whatsappUrl = 'https://wa.me/$phoneNumber';
    await launchUrlString(whatsappUrl);
  }

  static Future<void> launchPhone(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    // uid is fetched in initState for stream, but checked here for guest logic
    final uid = LocalStoreHelper.getUID();

    if (_isGuest == true || uid == null || uid.isEmpty) {
      return _buildScaffold(locale, null);
    }

    return StreamBuilder(
      stream: _customerStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
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

        // Show welcome modal for new registrations
        if (widget.isNewRegistration && snapshot.hasData && !_hasShownWelcome) {
          _hasShownWelcome = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              WelcomeModal.show(context);
            }
          });
        }

        return _buildScaffold(locale, customerData);
      },
    );
  }

  // Your screens/pages
  final List<Widget> _screens = [
    const HomePage(),
    const BookingsPage(),
    const AccountPage(),
  ];

  Widget _buildScaffold(AppLocalizations? locale, dynamic customerData) {
    Widget getCurrentPage() {
      final accountIndex = (_isGuest ?? false) ? 1 : 2;

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
              backgroundColor: Colors.white,
              actionsAlignment: MainAxisAlignment.start,
              title: Text(locale?.exitAppTitle ?? 'Exit App'),
              content: Text(
                locale?.exitAppMessage ??
                    'Are you sure you want to exit the app?',
              ),
              actions: [
                eButton(
                  onPressed: () => Navigator.of(context).pop(),
                  context: context,
                  backgroundColor: Colors.grey,
                  textColor: Colors.white,
                  text: locale?.cancel ?? 'Cancel',
                ),
                eButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  context: context,
                  backgroundColor: AppColors.red,
                  textColor: Colors.white,
                  text: locale?.exit ?? 'Exit',
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
        body: _screens[currentIndex],
        //  AnimatedSwitcher(
        //   duration: const Duration(milliseconds: 300),
        //   transitionBuilder: (Widget child, Animation<double> animation) {
        //     return FadeTransition(opacity: animation, child: child);
        //   },
        //   child: getCurrentPage(),
        // ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: CustomBottomNavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              isGuest: _isGuest ?? false,
              homeLabel: locale?.home ?? 'Home',
              myBookingLabel: locale?.myBooking ?? 'My Booking',
              accountLabel: locale?.account ?? 'Account',
            ),
          ),
        ),
        //  NavigationBar(
        //   selectedIndex: currentIndex,
        //   onDestinationSelected: (index) {
        //     if (mounted) setState(() => currentIndex = index);
        //   },
        //   height: 70,
        //   destinations: [
        //     NavigationDestination(
        //       icon: SvgPicture.asset(
        //         AppIcons.homeNav,
        //         colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
        //       ),
        //       selectedIcon: SvgPicture.asset(
        //         AppIcons.homeNav,
        //         colorFilter: ColorFilter.mode(
        //           AppColors.secondary,
        //           BlendMode.srcIn,
        //         ),
        //       ),
        //       label: locale?.home ?? '',
        //     ),
        //     // NavigationDestination(
        //     //   icon: SvgPicture.asset(
        //     //     AppIcons.categoriesNav,
        //     //     colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
        //     //   ),
        //     //   selectedIcon: SvgPicture.asset(
        //     //     AppIcons.categoriesNav,
        //     //     colorFilter: ColorFilter.mode(
        //     //       AppColors.secondary,
        //     //       BlendMode.srcIn,
        //     //     ),
        //     //   ),
        //     //   label: locale?.categories ?? '',
        //     // ),
        //     if (!(_isGuest ?? false))
        //       NavigationDestination(
        //         icon: SvgPicture.asset(
        //           AppIcons.myBookingNav,
        //           colorFilter: ColorFilter.mode(
        //             AppColors.grey,
        //             BlendMode.srcIn,
        //           ),
        //         ),
        //         selectedIcon: SvgPicture.asset(
        //           AppIcons.myBookingNav,
        //           colorFilter: ColorFilter.mode(
        //             AppColors.secondary,
        //             BlendMode.srcIn,
        //           ),
        //         ),
        //         label: locale?.myBooking ?? '',
        //       ),
        //     NavigationDestination(
        //       icon: SvgPicture.asset(
        //         AppIcons.profileNav,
        //         colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
        //       ),
        //       selectedIcon: SvgPicture.asset(
        //         AppIcons.profileNav,
        //         colorFilter: ColorFilter.mode(
        //           AppColors.secondary,
        //           BlendMode.srcIn,
        //         ),
        //       ),
        //       label: locale?.account ?? '',
        //     ),
        //   ],
        // ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: LanguageSelectorCard(isInLoginPage: false),
            ),
            const SizedBox(height: 30),
            const Icon(Icons.block, size: 100, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)?.accountBlocked ?? 'Account Blocked',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.yourAccountHasBeenBlocked ??
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
              AppLocalizations.of(context)!.pleaseContactSupport,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            StreamBuilder(
              stream: AppServices.getCustomerSupportdata(),
              builder: (context, asyncSnapshot) {
                if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(height: 50);
                }
                if (asyncSnapshot.hasError) {
                  return Center(
                    child: Text(
                      '${AppLocalizations.of(context)?.error ?? "Error"}: ${asyncSnapshot.error}',
                    ),
                  );
                }
                if (!asyncSnapshot.hasData || asyncSnapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)?.noSupportAvailable ??
                          "No support available",
                    ),
                  );
                }

                final data = asyncSnapshot.data!;
                for (int i = 0; i < data.length; i++) {
                  final item = data[i];
                  if (item.type == 'Phone') {
                    phone = item.detail;
                  }
                  if (item.type == 'WhatsApp') {
                    whatsapp = item.detail;
                  }
                  if (item.type == 'Email') {
                    email = item.detail;
                  }
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                  children: [
                    if (whatsapp.isNotEmpty) ...{
                      GestureDetector(
                        onTap: () async {
                          launchWhatsApp(whatsapp);
                        },
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 5,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Image.asset('assets/images/whatsapp.png'),
                            ),
                          ),
                        ),
                      ),
                    },
                    if (phone.isNotEmpty) ...{
                      GestureDetector(
                        onTap: () async {
                          launchPhone(phone);
                        },
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 5,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Image.asset('assets/images/phone.png'),
                            ),
                          ),
                        ),
                      ),
                    },
                    if (email.isNotEmpty) ...{
                      GestureDetector(
                        onTap: () async {
                          launchEmail(email);
                        },
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 5,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Image.asset(
                                'assets/images/email.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    },
                  ],
                );
              },
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
          backgroundColor: Colors.white,
          actionsAlignment: MainAxisAlignment.start,
          title: Text(
            AppLocalizations.of(context)?.logout ?? 'Logout',
            style: DMSansFont.textStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)?.areYouSureYouWantToLogout ??
                'Are you sure you want to logout?',
            style: DMSansFont.textStyle(fontSize: 16),
          ),
          actions: [
            eButton(
              onPressed: () async {
                Navigator.of(context).pop();
              },
              context: context,
              backgroundColor: Colors.white,
              textColor: Colors.black,
              text: AppLocalizations.of(context)?.cancel ?? 'Cancel',
            ),
            eButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              context: context,
              backgroundColor: AppColors.red,
              textColor: Colors.white,
              text: AppLocalizations.of(context)?.logout ?? 'Logout',
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
