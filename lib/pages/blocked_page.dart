import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/biometric_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';

class BlockedPage extends StatefulWidget {
  const BlockedPage({super.key});

  @override
  State<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends State<BlockedPage> {
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    _loadBiometricSettings();
    super.initState();
  }

  void _exitApp() {
    exit(0); // Exit the app completely
  }

  Future<void> _loadBiometricSettings() async {
    _isBiometricEnabled = await BiometricService.isBiometricEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Blocked'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.block, size: 100, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Your account has been blocked by the admin due to one or more of the following reasons:',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '- Violation of Terms and Conditions\n'
              '- Improper Conduct\n'
              '- Fraud or related activities',
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Please contact the administrator for more information on why your account was blocked and what steps you may take to unlock it.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _showLogoutConfirmationDialog,
              child: const Text('Logout'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _exitApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
              ),
              child: const Text('Exit App'),
            ),
          ],
        ),
      ),
    );
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
      if (_isBiometricEnabled == true) {
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
