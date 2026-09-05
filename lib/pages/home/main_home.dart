import 'dart:async';

import 'package:abo_glumbo_bbk/common_widgets/custom_navigation_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/welcome_modal.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/accounts/account.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bookings_page.dart';
import 'package:abo_glumbo_bbk/pages/home/home_page.dart';
import 'package:abo_glumbo_bbk/sheets/write_review.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<BookingModel>>? _completedBookingsSubscription;
  bool _isReviewSheetOpen = false;
  final Set<String> _sessionLaterBookings = {};
  List<BookingModel> _completedUnreviewedBookings = [];

  String whatsapp = "";
  String phone = "";
  String email = "";
  late final List<Widget> _pages;
  late final Stream<dynamic> _customerStream;

  @override
  void initState() {
    _isGuest = LocalStoreHelper.getGuestUser();
    if (widget.byPassedUid != null) {
      _isGuest = false;
    }
    if (widget.initialIndex != null) {
      currentIndex = widget.initialIndex!;
    }
    String? uid;
    if (widget.byPassedUid != null) {
      uid = widget.byPassedUid!;
      LocalStoreHelper.putUID(uid);
      LocalStoreHelper.putGuestUser(false);
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

      if (!(_isGuest ?? false) && uid != null && uid.isNotEmpty) {
        _subscribeToAcceptedBookings();
        _subscribeToCompletedBookings(uid);
      }
    });
  }

  void _subscribeToAcceptedBookings() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = AppServices.listenToAcceptedBookings().listen((
      bookings,
    ) {
      // Local tracking notifications (e.g., 'on_the_way') have been removed
      // to avoid duplicates with backend push notifications.
    });
  }

  void _subscribeToCompletedBookings(String uid) {
    _completedBookingsSubscription?.cancel();
    _completedBookingsSubscription = AppServices.listenToBookings(uid).listen((
      bookings,
    ) {
      if (mounted) {
        setState(() {
          _completedUnreviewedBookings = bookings.where((b) {
            return b.bookingStatusCode == 'C' &&
                (b.review == null || b.review?.rating == null) &&
                b.isRatingSheetShown != true;
          }).toList();
        });
        _checkAndShowPendingReviews();
      }
    });
  }

  void _checkAndShowPendingReviews() {
    if (_isReviewSheetOpen) return; // Don't show if already open
    if (_completedUnreviewedBookings.isEmpty) return; // Nothing to review

    BookingModel? bookingToReview;
    for (var b in _completedUnreviewedBookings) {
      if (b.isRatingSheetShown == true) continue;
      if (!_sessionLaterBookings.contains(b.id)) {
        // Only auto-show popup if completed in the last 15 minutes
        if (b.completedAt != null) {
          final diff = DateTime.now().difference(b.completedAt!.toDate());
          if (diff.inMinutes <= 15) {
            bookingToReview = b;
            break;
          }
        }
      }
    }

    if (bookingToReview == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure we are only showing the review sheet if the user is on the main tabs
        // and not currently inside a pushed sub-route (e.g. booking flow, booking completed screen)
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (isCurrentRoute) {
          _showReviewSheet(bookingToReview!);
        }
      }
    });
  }

  Future<void> _showReviewSheet(BookingModel booking) async {
    setState(() => _isReviewSheetOpen = true);

    // Track on the booking document that the rating sheet has been shown so it only appears once
    try {
      booking.isRatingSheetShown = true;
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        'isRatingSheetShown': true,
      });
    } catch (e) {
      debugPrint('Error marking isRatingSheetShown in Firestore: $e');
    }

    try {
      final result = await showWriteReviewBottomSheet(
        context,
        booking: booking,
        showLaterOption: true,
      );

      if (mounted) {
        if (result == 'later' || result == null) {
          setState(() {
            _sessionLaterBookings.add(booking.id);
          });
          _showLaterSnackBar();
        }
      }
    } catch (e) {
      debugPrint('Error showing review sheet: $e');
    } finally {
      if (mounted) {
        setState(() => _isReviewSheetOpen = false);
      }
    }
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _completedBookingsSubscription?.cancel();
    super.dispose();
  }


  void _showLaterSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _getReviewLaterSnackbarText(context),
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 80,
        ), // Elevated margin to avoid overlapping bottom bar
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getReviewLaterSnackbarText(BuildContext context) {
    final lang = LocalStoreHelper.getUserlanguage();
    if (lang == 'ar') {
      return 'يمكنك تقييم هذا الحجز في أي وقت من صفحة حجوزاتي.';
    }
    if (lang == 'ur') {
      return 'آپ اپنے بکنگ پیج سے کسی بھی وقت اس بکنگ کا ریویو کر سکتے ہیں۔';
    }
    return 'You can review this booking anytime from your Bookings page.';
  }



  static Future<void> launchEmail(String email) async {
    await launchUrlString("mailto:$email");
  }

  static Future<void> launchWhatsApp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUrl = 'https://wa.me/$cleanPhone';
    try {
      final success = await launchUrlString(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        await launchUrlString(whatsappUrl);
      }
    } catch (e) {
      try {
        await launchUrlString(whatsappUrl);
      } catch (err) {
        // Fail silently
      }
    }
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
            backgroundColor: AppColors.bgBlueTint,
            body: Center(child: Loader(color: AppColors.primary)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.bgBlueTint,
            body: Center(
              child: Text(
                '${locale?.error ?? "Error"}: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
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
          if (_isGuest == true) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.bgBlueTint,
                actionsAlignment: MainAxisAlignment.start,
                title: Text(locale?.backToLogin ?? 'Back to Login'),
                content: Text(
                  locale?.areYouSureYouWantToGoBackToLogin ??
                      'Are you sure you want to go back to the login screen?',
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
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                        (route) => false,
                      );
                    },
                    context: context,
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                    text: locale?.backToLogin ?? 'Back to Login',
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.bgBlueTint,
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
                    onPressed: () {
                      Navigator.of(context).pop();
                      SystemNavigator.pop();
                    },
                    context: context,
                    backgroundColor: AppColors.red,
                    textColor: Colors.white,
                    text: locale?.exit ?? 'Exit',
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            currentIndex = 0;
          });
          _checkAndShowPendingReviews();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBlueTint,
        extendBody: true,
        body: getCurrentPage(),
        bottomNavigationBar: CustomBottomNavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              currentIndex = index;
            });
            _checkAndShowPendingReviews();
          },
          isGuest: _isGuest ?? false,
          homeLabel: locale?.home ?? 'Home',
          myBookingLabel: locale?.bookings ?? 'Bookings',
          accountLabel: locale?.account ?? 'Account',
        ),
      ),
    );
  }

  Widget _buildBlockedScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bgBlueTint,
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
    SystemNavigator.pop(); // Exit the app completely
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.bgBlueTint,
          actionsAlignment: MainAxisAlignment.start,
          title: Text(
            AppLocalizations.of(context)?.logout ?? 'Logout',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            AppLocalizations.of(context)?.areYouSureYouWantToLogout ??
                'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            eButton(
              onPressed: () async {
                Navigator.of(context).pop();
              },
              context: context,
              backgroundColor: AppColors.bgWhite,
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
      final lastUid = LocalStoreHelper.getUID();
      bool keepFirebaseAuth = false;
      if (lastUid != null) {
        keepFirebaseAuth = LocalStoreHelper.getBiometricAuthEnabled(lastUid);
      }

      await LocalStoreHelper.putlogoutStatus(true);
      await LocalStoreHelper.putGuestUser(false);
      try {
        await AppServices.deleteFCMToken();
      } catch (e) {
        debugPrint('❌ Error deleting FCM token: $e');
      }

      LocalStoreHelper.clearUID();

      if (!keepFirebaseAuth) {
        await FirebaseAuth.instance.signOut();
      }

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
