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
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

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
      _currentLanguage = currentLocale.languageCode == 'ar'
          ? 'العربية'
          : 'English';

      // Initialize notification language from customer data
      if (widget.customerData?.lanCode != null) {
        _currentNotificationLanguage = widget.customerData!.lanCode == 'ar'
            ? 'العربية'
            : 'English';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, refreshing language state');
      final currentLocale = context.read<AccountBloc>().state.locale;
      final newLanguage = currentLocale.languageCode == 'ar'
          ? 'العربية'
          : 'English';
      if (_currentLanguage != newLanguage) {
        setState(() {
          _currentLanguage = newLanguage;
        });
        debugPrint('🔄 Updated language state to: $_currentLanguage');
      }
    }
  }

  Future<void> _loadBiometricSettings() async {
    _isBiometricEnabled = await BiometricService.isBiometricEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildProfileHeader(),
          _buildUserInfo(),
          if (!_isGuest) ...[_buildAccountSection()],
          _buildGeneralSettings(),
          _buildSupportSection(),
          if (!_isGuest) ...[_buildTermsAndConditions(), _buildPrivacyPolicy()],
          _buildFAQSection(),
          _buildAboutUsSection(),
          if (!_isGuest) ...[_buildAuthSection(), _buildDangerZone()],
          if (_isGuest) _buildAuthSection(),
        ],
      ),
    );
  }

  Widget _buildAboutUsSection() {
    return AccountListTile.withArrow(
      title: AppLocalizations.of(context)?.customerAboutUsTitle ?? '',
      onTap: _handleAboutUsPage,
    );
  }

  Widget _buildFAQSection() {
    return AccountListTile.withArrow(
      title: AppLocalizations.of(context)?.faq ?? '',
      onTap: _handleFAQPage,
    );
  }

  Widget _buildTermsAndConditions() {
    return AccountListTile.withArrow(
      title: AppLocalizations.of(context)?.termsAndConditions ?? '',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TermsAndConditionsPage(isFromLogin: false),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyPolicy() {
    return AccountListTile.withArrow(
      title: AppLocalizations.of(context)?.privacyPolicy ?? '',
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => PrivacyPolicyPage()));
      },
    );
  }

  Widget _buildProfileHeader() {
    return SizedBox(
      height: AccountPageConstants.profileHeaderHeight,
      child: Stack(
        children: [
          Container(
            width: double.maxFinite,
            height: AccountPageConstants.primaryContainerHeight,
            color: AppColors.primary,
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
                style: DMSansFont.textStyle(
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
            style: DMSansFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isGuest && widget.customerData?.email != null) ...[
            Text(
              widget.customerData!.email!,
              style: DMSansFont.textStyle(
                fontSize: 14,
                color: const Color(0xff757575),
              ),
            ),
          ],
          Text(
            "Version : ${AccountPageConstants.appVersion}",
            style: DMSansFont.textStyle(
              fontSize: 10,
              color: const Color(0xff757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AccountPageConstants.sectionSpacing),
        SectionHeader(title: AppLocalizations.of(context)?.account ?? ''),
        AccountListTile.withArrow(
          title: AppLocalizations.of(context)?.profileManagement ?? '',
          onTap: _handleProfileManagement,
        ),

        // AccountListTile.withArrow(
        //   title: AppLocalizations.of(context)?.wishlist ?? '',
        //   onTap: _handleWishlist,
        // ),
        AccountListTile.withArrow(
          title: AppLocalizations.of(context)?.notifications ?? '',
          onTap: _handleNotifications,
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return Column(
      children: [
        BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            final displayLanguage = state.locale.languageCode == 'en'
                ? 'English'
                : 'العربية';
            return AccountListTile.withText(
              title: AppLocalizations.of(context)?.language ?? '',
              trailingText: displayLanguage,
              onTap: _showLanguageSelection,
            );
          },
        ),
        if (!_isGuest)
          AccountListTile(
            title: AppLocalizations.of(context)?.notificationLanguage ?? '',
            onTap: _showNotificationLanguageSelection,
            trailing: const Icon(Icons.arrow_forward_ios_sharp, size: 15),
          ),
        if (!_isGuest) _buildSecuritySettings(),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return AccountListTile(
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
    );
  }

  Widget _buildSupportSection() {
    return AccountListTile.withArrow(
      title: AppLocalizations.of(context)?.contactUs ?? '',
      onTap: _showContactOptions,
    );
  }

  Widget _buildDangerZone() {
    return AccountListTile(
      textcolor: Colors.red,
      title: AppLocalizations.of(context)?.deleteAccount ?? '',
      onTap: () => _showDeleteAccountConfirmation(),
      dense: true,
      trailing: Icon(Icons.delete, color: Colors.red),
    );
  }

  Widget _buildAuthSection() {
    return AccountListTile(
      trailing: Icon(Icons.logout, size: 20),
      title: _isGuest
          ? (AppLocalizations.of(context)?.signUp ?? '')
          : (AppLocalizations.of(context)?.logout ?? ''),
      onTap: _handleAuthAction,
    );
  }

  void _handleProfileManagement() {
    if (widget.customerData == null) {
      showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ?? '',
        context,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(customer: widget.customerData!),
      ),
    );
  }

  void _handleFAQPage() {
    if (widget.customerData == null) {
      showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ?? '',
        context,
      );
      return;
    }
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
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        title: AppLocalizations.of(context)?.selectLanguage ?? '',
        currentLanguage: _currentLanguage,
        onEnglishSelected: () => _handleLanguageChange('English'),
        onArabicSelected: () => _handleLanguageChange('العربية'),
      ),
    );
  }

  void _showNotificationLanguageSelection() {
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        title: AppLocalizations.of(context)?.notificationLanguage ?? '',
        currentLanguage: _currentNotificationLanguage,
        onEnglishSelected: () => _handleNotificationLanguageChange('English'),
        onArabicSelected: () => _handleNotificationLanguageChange('العربية'),
      ),
    );
  }

  void _handleLanguageChange(String language) {
    if (mounted) {
      final languageCode = language == 'English' ? 'en' : 'ar';
      context.read<AccountBloc>().add(ChangeLocale(languageCode: languageCode));
      setState(() {
        _currentLanguage = language;
      });
    }
  }

  void _handleNotificationLanguageChange(String language) async {
    try {
      await AppServices.updateNotificationLanguage(
        language == 'English' ? 'en' : 'ar',
      );
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
            backgroundColor: Colors.white,
            actionsAlignment: MainAxisAlignment.start,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(dialogContext)?.disableBiometric ??
                        'Disable Biometric?',
                    style: DMSansFont.textStyle(
                      fontSize: 18,
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
                  style: DMSansFont.textStyle(fontSize: 14),
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
                          style: DMSansFont.textStyle(
                            fontSize: 13,
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
          backgroundColor: Colors.white,
          actionsAlignment: MainAxisAlignment.start,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(dialogContext)?.deleteAccount ??
                      'Delete Account?',
                  style: DMSansFont.textStyle(
                    fontSize: 18,
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
                style: DMSansFont.textStyle(
                  fontSize: 14,
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
                            style: DMSansFont.textStyle(
                              fontSize: 13,
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
            eButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              context: context,
              backgroundColor: Colors.white,
              textColor: Colors.black,
              text: AppLocalizations.of(dialogContext)?.cancel ?? 'Cancel',
            ),

            eButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              context: context,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              text:
                  AppLocalizations.of(dialogContext)?.deleteAccount ??
                  'Delete Account',
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
              style: DMSansFont.textStyle(
                fontSize: 12,
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
      await LocalStoreHelper.clearUID();
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
              context: context,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              text: AppLocalizations.of(context)?.logout ?? 'Logout',
            ),
            SizedBox(width: 8),
            eButton(
              context: context,
              backgroundColor: Colors.white,
              textColor: Colors.black,
              onPressed: () {
                Navigator.of(context).pop();
              },
              text: AppLocalizations.of(context)?.cancel ?? 'Cancel',
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
      if (!_isBiometricEnabled) {
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
