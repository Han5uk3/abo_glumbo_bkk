import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/constants.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/accounts/edit_profile.dart';
import 'package:abo_glumbo_bbk/pages/accounts/notification.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/account_list_tile.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/contact_bottom_sheet.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/language_dialog.dart';
import 'package:abo_glumbo_bbk/pages/accounts/wishlist.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/biometric_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountPage extends StatefulWidget {
  final CustomerModel? customerData;
  const AccountPage({super.key, this.customerData});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with WidgetsBindingObserver {
  bool _isBiometricEnabled = false;
  String _currentLanguage = 'English';
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
          if (!_isGuest) _buildDangerZone(),
          _buildAuthSection(),
        ],
      ),
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
                style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isGuest && widget.customerData?.email != null) ...[
            Text(
              widget.customerData!.email!,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xff757575),
              ),
            ),
          ],
          Text(
            "Version : ${AccountPageConstants.appVersion}",
            style: GoogleFonts.dmSans(
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
        AccountListTile.withArrow(
          title: AppLocalizations.of(context)?.wishlist ?? '',
          onTap: _handleWishlist,
        ),
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
      title: AppLocalizations.of(context)?.deleteAccount ?? '',
      onTap: () => _showDeleteAccountConfirmationDialog(),
      dense: true,
    );
  }

  Widget _buildAuthSection() {
    return AccountListTile(
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

  void _handleWishlist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WishListPage()),
    );
  }

  void _handleNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }

  void _showLanguageSelection() {
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        title: AppLocalizations.of(context)?.selectLanguage ?? '',
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
      final authenticated = await BiometricService.authenticate(context);
      if (authenticated && mounted) {
        setState(() => _isBiometricEnabled = true);
        await BiometricService.setBiometricEnabled(true);
      }
    } else {
      if (mounted) {
        setState(() => _isBiometricEnabled = false);
      }
      await BiometricService.setBiometricEnabled(false);
    }
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ContactBottomSheet(),
    );
  }

  void _showDeleteAccountConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.red,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)?.areYouSureYouWantToDeleteAccount ??
                'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
            style: GoogleFonts.dmSans(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
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
                Navigator.of(context).pop(); // Close dialog
                await _performDeleteAccount();
              },
              child: Text(
                AppLocalizations.of(context)?.deleteAccount ?? 'Delete',
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

  Future<void> _performDeleteAccount() async {
    try {
      await AppServices.deleteAccount();
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
      if (!_isBiometricEnabled) {
        await LocalStoreHelper.clearUID();
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
