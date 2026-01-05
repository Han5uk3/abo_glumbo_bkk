import 'dart:async';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/services/sms_autofill_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class OtpPage extends StatefulWidget {
  final String? phoneNumber;
  final String? verificationId;
  final bool? isFromProfile;
  const OtpPage({
    super.key,
    this.phoneNumber,
    this.verificationId,
    this.isFromProfile,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  bool isLoading = false;
  bool isResendingOtp = false;
  bool _isMigratingCustomerData = false;
  bool _isSmsAutofillListening = false;
  int resendSeconds = 60;
  Timer? _timer;
  Timer? _smsListeningTimer;
  final _formKey = GlobalKey<FormState>();
  final otpController = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _isDialogShowing = false;
  final SmsAutofillService _smsAutofillService = SmsAutofillService();

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    startTimer();
    _startSmsAutofillListener();
  }

  int get _remainingTime => resendSeconds;
  String get _formattedTime {
    int minutes = resendSeconds ~/ 60;
    int seconds = resendSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void startTimer() {
    _timer?.cancel();
    resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds > 0) {
        if (mounted) {
          setState(() {
            resendSeconds--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void resendOTP() async {
    if (resendSeconds > 0) {
      debugPrint(
        '🚫 [CUSTOMER OTP] Cannot resend - timer still active: $resendSeconds seconds remaining',
      );
      return;
    }

    debugPrint('🔄 [CUSTOMER OTP] Starting resend OTP process');
    debugPrint('📱 [CUSTOMER OTP] Phone number: ${widget.phoneNumber}');
    debugPrint('🔑 [CUSTOMER OTP] Current resend token: $_resendToken');
    debugPrint('🆔 [CUSTOMER OTP] Current verification ID: $_verificationId');

    setState(() {
      isResendingOtp = true;
    });
    debugPrint('⏳ [CUSTOMER OTP] Loading state set to TRUE');

    try {
      debugPrint('📞 [CUSTOMER OTP] Calling AuthServices().resendOTP...');
      await AuthServices().resendOTP(
        phoneNumber: widget.phoneNumber ?? '',
        resendToken: _resendToken,
        onCodeSent: (verificationId, {int? resendToken}) {
          debugPrint('✅ [CUSTOMER OTP] onCodeSent callback triggered!');
          debugPrint('🆔 [CUSTOMER OTP] New verification ID: $verificationId');
          debugPrint('🔑 [CUSTOMER OTP] New resend token: $resendToken');

          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.otpSent),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            startTimer();
            debugPrint('⏱️ [CUSTOMER OTP] Timer restarted');
          }
        },
        onError: (error) {
          debugPrint('❌ [CUSTOMER OTP] onError callback triggered');
          debugPrint('❌ [CUSTOMER OTP] Error code: ${error.code}');
          debugPrint('❌ [CUSTOMER OTP] Error message: ${error.message}');

          if (mounted) {
            String errorMessage;
            switch (error.code) {
              case 'too-many-requests':
                errorMessage =
                    AppLocalizations.of(context)?.tooManyAttempts ??
                    'Too many attempts. Please wait and try again.';
                break;
              case 'quota-exceeded':
                errorMessage =
                    AppLocalizations.of(context)?.quotaExceeded ??
                    'SMS quota exceeded. Try again later.';
                break;
              case 'network-request-failed':
                errorMessage =
                    AppLocalizations.of(context)?.networkError ??
                    'Network error. Please check your connection.';
                break;
              case 'session-expired':
                errorMessage =
                    AppLocalizations.of(context)?.otpExpired ??
                    'OTP expired. Please request a new OTP.';
                break;
              case 'internal-error':
                errorMessage =
                    AppLocalizations.of(context)?.internalError ??
                    'An internal error occurred. Please try again later.';
                break;
              default:
                errorMessage = error.message ?? 'Failed to resend OTP';
            }

            debugPrint(
              '📢 [CUSTOMER OTP] Showing error message: $errorMessage',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      );
      debugPrint(
        '✅ [CUSTOMER OTP] AuthServices().resendOTP completed (await finished)',
      );
    } catch (e) {
      debugPrint('💥 [CUSTOMER OTP] Exception caught in try-catch: $e');
      debugPrint('💥 [CUSTOMER OTP] Exception type: ${e.runtimeType}');

      // Catch any unexpected errors that weren't handled by onError callback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      debugPrint('🏁 [CUSTOMER OTP] Finally block executing');
      // Always reset the loading state, regardless of success or failure
      if (mounted) {
        setState(() {
          isResendingOtp = false;
        });
        debugPrint('⏳ [CUSTOMER OTP] Loading state set to FALSE');
      }
      debugPrint('🏁 [CUSTOMER OTP] Resend OTP process complete');
    }
  }

  Future<void> migrateUserData(
    String oldUid,
    String newUid,
    String newPhone,
  ) async {
    try {
      if (mounted) {
        setState(() => _isMigratingCustomerData = true);
        _showMigrationDialog();
      }

      final oldCustomerDoc = await AppFirestore.customersCollectionRef
          .doc(oldUid)
          .get();
      if (oldCustomerDoc.exists) {
        final oldData = oldCustomerDoc.data() as Map<String, dynamic>;
        final newData = <String, dynamic>{
          ...oldData,
          'uid': newUid,
          'phone': newPhone,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await AppFirestore.customersCollectionRef.doc(newUid).set(newData);
      }

      final bookingsQuery = await AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: oldUid)
          .get();
      if (bookingsQuery.docs.isNotEmpty) {
        for (final bookingDoc in bookingsQuery.docs) {
          final Map<String, dynamic> updatedCustomer =
              Map<String, dynamic>.from(bookingDoc['customer'] ?? {});
          updatedCustomer['uid'] = newUid;
          updatedCustomer['phone'] = newPhone;
          updatedCustomer['updatedAt'] = FieldValue.serverTimestamp();

          await AppFirestore.bookingsCollectionRef.doc(bookingDoc.id).update({
            'customer': updatedCustomer,
            'phone': newPhone,
            'uid': newUid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final notificationQuery = await AppFirestore.notificationsCollectionRef
          .where('userId', isEqualTo: oldUid)
          .get();
      if (notificationQuery.docs.isNotEmpty) {
        for (final notificationDoc in notificationQuery.docs) {
          await AppFirestore.notificationsCollectionRef
              .doc(notificationDoc.id)
              .delete();
        }
      }

      await AppFirestore.customersCollectionRef.doc(oldUid).delete();

      if (mounted) {
        setState(() => _isMigratingCustomerData = false);
        _closeMigrationDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMigratingCustomerData = false);
        _closeMigrationDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.unexpectedErrorOccurred}: $e',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void verifyOtp() async {
    if (!_formKey.currentState!.validate() || isLoading) return;

    setState(() {
      isLoading = true;
    });

    final otp = otpController.text.trim();
    final verificationId = _verificationId ?? widget.verificationId;

    if (verificationId == null) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification ID not found. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final UserCredential userCredential = await AuthServices().verifyOTP(
        context,
        otp,
        verificationId: verificationId,
        smsCode: otp,
      );
      if (widget.isFromProfile == true) {
        final String oldUid = LocalStoreHelper.getUID() ?? '';
        final String newUid = userCredential.user?.uid ?? '';
        if (oldUid != null && newUid != null && oldUid != newUid) {
          await migrateUserData(
            oldUid,
            newUid,
            userCredential.user?.phoneNumber ?? '',
          );
        }
        LocalStoreHelper.clearGuestUser();
        LocalStoreHelper.clearUID();
        LocalStoreHelper.putlogoutStatus(true);
        await FirebaseAuth.instance.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => isLoading = false);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        await AuthServices().checkUser(
          userCredential: userCredential,
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        String errorMessage = AppLocalizations.of(
          context,
        )!.invalidOtpCode; // Localized message for invalid OTP
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'invalid-verification-code':
              errorMessage = AppLocalizations.of(
                context,
              )!.invalidOtpCode; // Localized message for invalid OTP
              break;
            case 'session-expired':
              errorMessage = AppLocalizations.of(
                context,
              )!.otpExpired; // Localized message for expired OTP
              break;
            case 'too-many-requests':
              errorMessage =
                  AppLocalizations.of(context)?.tooManyAttempts ??
                  'Too many attempts. Please wait and try again.';
              break;
            case 'network-request-failed':
              errorMessage =
                  AppLocalizations.of(context)?.networkError ??
                  'Network error. Please check your connection.';
              break;
            case 'quota-exceeded':
              errorMessage =
                  AppLocalizations.of(context)?.quotaExceeded ??
                  'SMS quota exceeded. Try again later.';
              break;
            case 'internal-error':
              errorMessage =
                  AppLocalizations.of(context)?.internalError ??
                  'An internal error occurred. Please try again later.';
              break;
            default:
              errorMessage =
                  e.message ?? 'Verification failed. Please try again.';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Start listening for incoming SMS
  void _startSmsAutofillListener() {
    debugPrint('🎯 [CUSTOMER OTP] Starting SMS autofill listener...');

    if (!mounted) return;

    setState(() {
      _isSmsAutofillListening = true;
    });

    // Set a timeout for SMS listening (30 seconds)
    _smsListeningTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isSmsAutofillListening = false;
        });
        _smsAutofillService.cancelListening();
        debugPrint('⏰ [CUSTOMER OTP] SMS listening timeout reached');
      }
    });

    _listenForSmsCode();
  }

  /// Listen for SMS code and auto-fill the OTP field
  void _listenForSmsCode() async {
    try {
      debugPrint('👂 [CUSTOMER OTP] Listening for SMS code...');

      final smsCode = await _smsAutofillService.listenForSms(
        timeout: const Duration(seconds: 30),
      );

      if (smsCode != null && smsCode.isNotEmpty && mounted) {
        debugPrint('✅ [CUSTOMER OTP] SMS code received: $smsCode');

        // Fill the OTP field with the received code
        otpController.text = smsCode;

        // Clear the form to reset validation
        _formKey.currentState?.reset();

        setState(() {
          _isSmsAutofillListening = false;
        });

        // Cancel the listening timer
        _smsListeningTimer?.cancel();

        // Automatically verify the OTP after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          debugPrint('🔐 [CUSTOMER OTP] Auto-verifying OTP from SMS...');
          verifyOtp();
        }
      }
    } catch (e) {
      debugPrint('❌ [CUSTOMER OTP] Error listening for SMS: $e');
      if (mounted) {
        setState(() {
          _isSmsAutofillListening = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smsListeningTimer?.cancel();
    _smsAutofillService.cancelListening();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locn = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(centerTitle: true, backgroundColor: AppColors.primary),
      body: AbsorbPointer(
        absorbing: _isMigratingCustomerData,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        locn.otpVerification,
                        style: DMSansFont.textStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: locn.enterTheOtpSentToTheNumber,
                                style: DMSansFont.textStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        " ${widget.phoneNumber} ",
                                        style: DMSansFont.textStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        locn.enterOtp,
                        style: DMSansFont.textStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          obscureText: true,
                          obscuringCharacter: "*",
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: DMSansFont.textStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            helperText: _isSmsAutofillListening
                                ? '🎯 Listening for SMS...'
                                : null,
                            helperStyle: DMSansFont.textStyle(
                              fontSize: 12,
                              color: AppColors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _isSmsAutofillListening
                                    ? AppColors.green
                                    : AppColors.green,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.1),
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return locn.enterOtp;
                            }
                            return null;
                          },
                          onChanged: (value) {
                            if (value.length == 6) {
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _remainingTime > 0
                                ? '${locn.resend} ($_formattedTime)'
                                : AppLocalizations.of(context)!.didntreciveCode,
                            style: DMSansFont.textStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          if (_remainingTime <= 0) ...[
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: isResendingOtp ? null : resendOTP,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: isResendingOtp
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.green,
                                      ),
                                    )
                                  : Text(
                                      locn.resend,
                                      style: DMSansFont.textStyle(
                                        color: AppColors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: AppColors.secondary
                                .withOpacity(0.7),
                          ),
                          child: isLoading
                              ? Loader(color: Colors.white, size: 24)
                              : Text(
                                  locn.verifyOtp,
                                  style: DMSansFont.textStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closeMigrationDialog() {
    if (_isDialogShowing && mounted) {
      _isDialogShowing = false;
      Navigator.of(context).pop();
    }
  }

  void _showMigrationDialog() {
    if (!_isDialogShowing && mounted) {
      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.85),
        builder: (context) => _migratingDataDialog(),
      );
    }
  }

  Widget _migratingDataDialog() {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(32),
      content: WillPopScope(
        onWillPop: () async => false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.sync_alt_rounded,
                  size: 40,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Loader(),
            const SizedBox(height: 28),
            Text(
              AppLocalizations.of(context)!.migratingData,
              style: DMSansFont.textStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.weAreMigratingYourData,
              textAlign: TextAlign.center,
              style: DMSansFont.textStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.pleaseDontCloseTheApp,
                      style: DMSansFont.textStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.transferringData,
              style: DMSansFont.textStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
