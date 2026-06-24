import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/constants.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/privacy_policy_page.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/terms_and_conditions_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/accounts/edit_profile.dart';
import 'package:abo_glumbo_bbk/pages/accounts/notification.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/about_us_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/account_list_tile.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/contact_bottom_sheet.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/faq_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/language_dialog.dart';
// import 'package:abo_glumbo_bbk/pages/accounts/wishlist.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/biometric_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccountPage extends StatefulWidget {
  final CustomerModel? customerData;
  const AccountPage({super.key, this.customerData});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with WidgetsBindingObserver {
  bool _isBiometricEnabled = false;
  String _currentLanguage = 'English';
  String _currentNotificationLanguage = 'English';
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isGuest = LocalStoreHelper.getGuestUser();
    _loadBiometricSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentLocale = context.read<AccountBloc>().state.locale;
      _currentLanguage = _getDisplayLanguage(currentLocale.languageCode);

      // Initialize notification language from customer data
      if (widget.customerData?.lanCode != null) {
        _currentNotificationLanguage = _getDisplayLanguage(
          widget.customerData!.lanCode!,
        );
      }

      debugPrint(
        '🔄 Account Page: Synced language with bloc: $_currentLanguage',
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static String _getDisplayLanguage(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'ur':
        return 'اردو';
      default:
        return 'English';
    }
  }

  static String _getLanguageCode(String displayLanguage) {
    switch (displayLanguage) {
      case 'العربية':
        return 'ar';
      case 'اردو':
        return 'ur';
      default:
        return 'en';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, refreshing language state');
      final currentLocale = context.read<AccountBloc>().state.locale;
      final newLanguage = _getDisplayLanguage(currentLocale.languageCode);
      if (_currentLanguage != newLanguage) {
        setState(() {
          _currentLanguage = newLanguage;
        });
        debugPrint('🔄 Updated language state to: $_currentLanguage');
      }
    }
  }

  Future<void> _loadBiometricSettings() async {
    bool isEnabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlueTint,

      body: CustomScrollView(
        physics: ClampingScrollPhysics(),
        slivers: [
          SliverAppBar(
            centerTitle: true,
            floating: false,

            backgroundColor: AppColors.primary,
            title: Text(
              AppLocalizations.of(context)!.account,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildProfileHeader(),
              _buildUserInfo(),
              if (!_isGuest) ...[_buildAccountSection()],
              _buildGeneralSettings(),
              _buildSupportSection(),
              if (!_isGuest) ...[
                _buildTermsAndConditions(),
                _buildPrivacyPolicy(),
              ],
              _buildFAQSection(),
              _buildAboutUsSection(),
              if (!_isGuest) ...[_buildDangerZone(), _buildAuthSection()],
              if (_isGuest) _buildAuthSection(),
              const SizedBox(height: 106),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutUsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AccountListTile.withArrow(
        leading: Icon(Icons.info_outline),
        title: AppLocalizations.of(context)?.customerAboutUsTitle ?? '',
        onTap: _handleAboutUsPage,
      ),
    );
  }

  Widget _buildFAQSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AccountListTile.withArrow(
        leading: Icon(Icons.question_mark_outlined),
        title: AppLocalizations.of(context)?.faq ?? '',
        onTap: _handleFAQPage,
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AccountListTile.withArrow(
        leading: Icon(Icons.description_outlined),
        title: AppLocalizations.of(context)?.termsAndConditions ?? '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TermsAndConditionsPage(isFromLogin: false),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AccountListTile.withArrow(
        leading: Icon(Icons.privacy_tip_outlined),
        title: AppLocalizations.of(context)?.privacyPolicy ?? '',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => PrivacyPolicyPage()));
        },
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.23,
      child: Stack(
        children: [
          Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(color: AppColors.primary),
            child: Stack(
              children: [
                SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.18,
                  child: Image.asset(
                    "assets/images/appbarbg.png",
                    fit: BoxFit.fitHeight,
                    repeat: ImageRepeat.repeat,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CircleAvatar(
              radius: AccountPageConstants.avatarRadius,
              backgroundColor: AppColors.yellow,
              child: Text(
                widget.customerData?.name?.substring(0, 1) ?? 'G',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AccountPageConstants.avatarFontSize,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Padding(
      padding: AccountPageConstants.horizontalPadding.copyWith(top: 30),
      child: Column(
        children: [
          Text(
            widget.customerData?.name ?? 'Guest User',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isGuest && widget.customerData?.email != null) ...[
            Text(
              widget.customerData!.email!,
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
          ],
          // Text(
          //   "Version : ${AccountPageConstants.appVersion}",
          //   style: TextStyle(
          //     fontSize: 8,
          //     color: const Color(0xff757575),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AccountPageConstants.sectionSpacing),
          // SectionHeader(title: AppLocalizations.of(context)?.account ?? ''),
          AccountListTile.withArrow(
            leading: Icon(Icons.person_outline),
            title: AppLocalizations.of(context)?.profileManagement ?? '',
            onTap: _handleProfileManagement,
          ),

          // AccountListTile.withArrow(
          //   title: AppLocalizations.of(context)?.wishlist ?? '',
          //   onTap: _handleWishlist,
          // ),
          AccountListTile.withArrow(
            leading: Icon(Icons.notifications_outlined),
            title: AppLocalizations.of(context)?.notifications ?? '',
            onTap: _handleNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          BlocBuilder<AccountBloc, AccountState>(
            builder: (context, state) {
              final displayLanguage = _getDisplayLanguage(
                state.locale.languageCode,
              );
              return AccountListTile.withText(
                leading: Icon(Icons.translate),
                title: AppLocalizations.of(context)?.language ?? '',
                trailingText: displayLanguage,
                onTap: _showLanguageSelection,
              );
            },
          ),
          if (!_isGuest)
            AccountListTile(
              leading: Icon(Icons.language),
              title: AppLocalizations.of(context)?.notificationLanguage ?? '',
              onTap: _showNotificationLanguageSelection,
              trailing: const Icon(Icons.arrow_forward_ios_sharp, size: 15),
            ),
          if (!_isGuest) _buildSecuritySettings(),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: AccountListTile(
        leading: Icon(Icons.fingerprint),
        title: AppLocalizations.of(context)?.bioMetricAuthentication ?? '',
        trailing: SizedBox(
          width: 50,
          height: 40,
          child: FittedBox(
            fit: BoxFit.fill,
            child: Switch(
              value: _isBiometricEnabled,
              onChanged: _handleBiometricToggle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AccountListTile.withArrow(
        leading: Icon(Icons.support_agent),
        title: AppLocalizations.of(context)?.contactUs ?? '',
        onTap: _showContactOptions,
      ),
    );
  }

  Widget _buildDangerZone() {
    // Hidden per user request
    return const SizedBox.shrink();
  }

  Widget _buildAuthSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AccountListTile(
        leading: Icon(Icons.logout),
        title: _isGuest
            ? (AppLocalizations.of(context)?.signUp ?? '')
            : (AppLocalizations.of(context)?.logout ?? ''),
        onTap: _handleAuthAction,
      ),
    );
  }

  void _handleProfileManagement() {
    if (widget.customerData == null) {
      showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ??
            'Profile data not available. Please refresh.',
        context,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(customer: widget.customerData),
      ),
    );
  }

  void _handleFAQPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FAQPage()));
  }

  void _handleAboutUsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomerAboutUsPage()),
    );
  }

  // void _handleWishlist() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => const WishListPage()),
  //   );
  // }

  void _handleNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewNotificationsPage()),
    );
  }

  void _showLanguageSelection() {
    final currentCode = context.read<AccountBloc>().state.locale.languageCode;
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        title: AppLocalizations.of(context)?.selectLanguage ?? '',
        currentLanguageCode: currentCode,
        onEnglishSelected: () => _handleLanguageChange('English'),
        onArabicSelected: () => _handleLanguageChange('العربية'),
        onUrduSelected: () => _handleLanguageChange('اردو'),
      ),
    );
  }

  void _showNotificationLanguageSelection() {
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        title: AppLocalizations.of(context)?.notificationLanguage ?? '',
        currentLanguageCode: _getLanguageCode(_currentNotificationLanguage),
        onEnglishSelected: () => _handleNotificationLanguageChange('English'),
        onArabicSelected: () => _handleNotificationLanguageChange('العربية'),
        onUrduSelected: () => _handleNotificationLanguageChange('اردو'),
      ),
    );
  }

  void _handleLanguageChange(String language) {
    if (mounted) {
      final languageCode = _getLanguageCode(language);
      context.read<AccountBloc>().add(ChangeLocale(languageCode: languageCode));
      setState(() {
        _currentLanguage = language;
      });
    }
  }

  void _handleNotificationLanguageChange(String language) async {
    try {
      await AppServices.updateNotificationLanguage(_getLanguageCode(language));
      // Update local state
      setState(() {
        _currentNotificationLanguage = language;
      });
    } catch (e) {
      debugPrint('❌ Error changing locale: $e');
      return;
    }
    showSnackBar(
      AppLocalizations.of(context)?.notificationLanguageChanged ?? '',
      context,
      backgroundColor: AppColors.green,
    );
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value) {
      // Enabling biometric - authenticate first
      final authenticated = await BiometricService.authenticate(context);
      if (authenticated && mounted) {
        setState(() => _isBiometricEnabled = true);
        BiometricService.setBiometricEnabled(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.biometricEnabled ??
                    'Biometric authentication enabled',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      // Disabling biometric - show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.bgBlueTint,
            actionsAlignment: MainAxisAlignment.start,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(dialogContext)?.disableBiometric ??
                        'Disable Biometric?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(dialogContext)?.disableBiometricWarning ??
                      'Disabling biometric authentication will prevent you from logging in using fingerprint or face recognition.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(
                                dialogContext,
                              )?.youWillNeedPhoneOtp ??
                              'You will need to use your phone number and OTP to login.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              eButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                context: dialogContext,
                backgroundColor: Colors.grey,
                text: AppLocalizations.of(dialogContext)?.cancel,
                textColor: Colors.white,
              ),
              eButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                context: dialogContext,
                backgroundColor: Colors.red,
                text: AppLocalizations.of(dialogContext)?.disable,
                textColor: Colors.white,
              ),
            ],
          );
        },
      );

      // If user confirmed, disable biometric
      if (confirmed == true && mounted) {
        setState(() => _isBiometricEnabled = false);
        BiometricService.setBiometricEnabled(false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.biometricDisabled ??
                    'Biometric authentication disabled',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const ContactBottomSheet(),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgBlueTint,
          actionsAlignment: MainAxisAlignment.start,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(dialogContext)?.deleteAccount ??
                      'Delete Account?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(dialogContext)?.deleteAccountWarning ??
                    'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                                  dialogContext,
                                )?.whatWillBeDeleted ??
                                'What will be deleted:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDeleteItem(
                      dialogContext,
                      AppLocalizations.of(dialogContext)?.personalInfo ??
                          'Personal information',
                    ),
                    _buildDeleteItem(
                      dialogContext,
                      AppLocalizations.of(dialogContext)?.bookingHistory ??
                          'Booking history',
                    ),
                    _buildDeleteItem(
                      dialogContext,
                      AppLocalizations.of(dialogContext)?.documents ??
                          'Uploaded documents',
                    ),
                    _buildDeleteItem(
                      dialogContext,
                      AppLocalizations.of(dialogContext)?.allData ??
                          'All associated data',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: eButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    context: context,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,

                    text:
                        AppLocalizations.of(dialogContext)?.deleteAccount ??
                        'Delete Account',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: eButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    context: context,
                    backgroundColor: AppColors.bgBlueTint,
                    textColor: Colors.black,
                    text:
                        AppLocalizations.of(dialogContext)?.cancel ?? 'Cancel',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _performDeleteAccount();
    }
  }

  Widget _buildDeleteItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    try {
      await AppServices.deleteAccount();
      final uid =
          LocalStoreHelper.getUID() ?? LocalStoreHelper.getLastValidUID();
      if (uid != null) {
        await LocalStoreHelper.clearBiometricAuthEnabled(uid);
      }
      await LocalStoreHelper.clearUID();
      await LocalStoreHelper.clearLastValidUID();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      if (mounted) {
        showSnackBar(
          'Failed to delete account. Please try again.',
          context,
          backgroundColor: AppColors.red,
        );
      }
    }
  }

  void _handleAuthAction() {
    if (_isGuest) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } else {
      _showLogoutConfirmationDialog();
    }
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)?.areYouSureYouWantToLogout ??
                'Are you sure you want to logout?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: eButton(
                    context: context,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _performLogout();
                    },
                    text: AppLocalizations.of(context)?.logout ?? 'Logout',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: eButton(
                    context: context,
                    backgroundColor: AppColors.bgBlueTint,
                    textColor: Colors.black,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    text: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                  ),
                ),
              ],
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
