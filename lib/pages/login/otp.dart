import 'dart:async';
import 'dart:io';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/country_code_detector.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/services/sms_autofill_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OtpPage extends StatefulWidget {
  final String? phoneNumber;
  final String? verificationId;
  final bool? isFromProfile;

  /// Set when Android verified the number without sending an SMS; the page
  /// signs in with it straight away instead of waiting for a code.
  final PhoneAuthCredential? autoVerifiedCredential;
  const OtpPage({
    super.key,
    this.phoneNumber,
    this.verificationId,
    this.isFromProfile,
    this.autoVerifiedCredential,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  bool isLoading = false;
  bool isResendingOtp = false;
  bool _isMigratingCustomerData = false;
  bool _isSmsAutofillListening = false;
  final ValueNotifier<int> _resendSecondsNotifier = ValueNotifier<int>(60);
  Timer? _timer;
  int _smsListenGeneration = 0;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _verificationId;
  int? _resendToken;
  bool _isDialogShowing = false;
  final SmsAutofillService _smsAutofillService = SmsAutofillService();
  StreamSubscription<({String phoneNumber, PhoneAuthCredential credential})>?
  _autoVerifiedSub;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    startTimer();

    // Android may read the SMS itself; sign in with that instead of asking
    // the user. Ignore credentials for any other number from an earlier try.
    final myNumber = CountryCodeDetector.normalizeSaudiPhone(
      widget.phoneNumber ?? '',
    );
    _autoVerifiedSub = AuthServices.autoVerifiedCredentials.listen((event) {
      if (event.phoneNumber == myNumber) {
        _verifyAutoCredential(event.credential);
      }
    });

    final instantCredential = widget.autoVerifiedCredential;
    if (instantCredential != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _verifyAutoCredential(instantCredential),
      );
    } else {
      _startSmsAutofillListener();
    }
  }

  // Get the complete OTP from all controllers
  String get _fullOtp => _otpController.text;


  void startTimer() {
    _timer?.cancel();
    _resendSecondsNotifier.value = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsNotifier.value > 0) {
        if (mounted) {
          _resendSecondsNotifier.value--;
        }
      } else {
        timer.cancel();
      }
    });
  }

  void resendOTP() async {
    if (_resendSecondsNotifier.value > 0) {
      debugPrint(
        '🚫 [CUSTOMER OTP] Cannot resend - timer still active: ${_resendSecondsNotifier.value} seconds remaining',
      );
      return;
    }
    if (isResendingOtp) return;

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

              // Clear all OTP fields when resending
              _otpController.clear();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)?.otpSent ?? 'OTP Sent',
                ),
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
            _startSmsAutofillListener();
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
                content: Text(errorMessage.isEmpty ? 'Verification Failed' : errorMessage),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.failedResendOtp ?? 'Failed to resend OTP. Please try again.'),
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
              .update({'userId': newUid});
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
    if (isLoading) return;

    final otp = _fullOtp;

    // Validate OTP length
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.enterOtp ?? 'Enter OTP'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final verificationId = _verificationId ?? widget.verificationId;

    if (verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.verificationIdNotFound ?? 'Verification ID not found. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _signInAndContinue(
      () => AuthServices().verifyOTP(
        context,
        otp,
        verificationId: verificationId,
        smsCode: otp,
      ),
    );
  }

  /// Android verified the number itself (read the SMS, or needed none).
  void _verifyAutoCredential(PhoneAuthCredential credential) {
    if (isLoading || !mounted) return;
    debugPrint('✅ [CUSTOMER OTP] Signing in with auto-verified credential');
    // The code is in hand, so Google's "share this SMS?" prompt is not needed.
    _smsAutofillService.cancelListening();
    _signInAndContinue(
      () => AuthServices().signInWithAutoVerifiedCredential(credential),
      codeToShow: credential.smsCode,
    );
  }

  /// Runs [signIn], then routes the same way for a typed, shared or
  /// auto-verified code: profile phone change, or checkUser for login.
  Future<void> _signInAndContinue(
    Future<UserCredential> Function() signIn, {
    String? codeToShow,
  }) async {
    setState(() {
      isLoading = true;
    });
    if (codeToShow != null && codeToShow.isNotEmpty) {
      _otpController.text = codeToShow;
    }

    try {
      final UserCredential userCredential = await signIn();
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

        String errorMessage =
            AppLocalizations.of(context)?.invalidOtpCode ?? 'Invalid OTP code';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'invalid-verification-code':
              errorMessage = AppLocalizations.of(context)?.invalidOtpCode ??
                  'Invalid OTP code';
              break;
            case 'session-expired':
              errorMessage =
                  AppLocalizations.of(context)?.otpExpired ?? 'OTP expired';
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
            content: Text(errorMessage.isEmpty ? 'Error' : errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Clear all OTP fields on error
        _otpController.clear();
        // Focus on first field
        _focusNode.requestFocus();
      }
    }
  }

  /// Android only: Google asks the user to share the OTP SMS, then the code
  /// is filled in and verified. On iOS the keyboard offers the code from
  /// Messages instead, through Pinput's default oneTimeCode autofill hint.
  /// Called when the page opens (first send) and after every resend.
  void _startSmsAutofillListener() {
    if (!Platform.isAndroid || !mounted) return;
    debugPrint('🎯 [CUSTOMER OTP] Starting SMS autofill listener...');

    setState(() {
      _isSmsAutofillListening = true;
    });

    _listenForSmsCode(++_smsListenGeneration);
  }

  void _listenForSmsCode(int generation) async {
    try {
      debugPrint('👂 [CUSTOMER OTP] Listening for SMS code...');

      final smsCode = await _smsAutofillService.listenForSms(
        timeout: const Duration(minutes: 5),
      );

      // A resend restarted listening; the newer listener owns the UI.
      if (!mounted || generation != _smsListenGeneration) return;

      setState(() {
        _isSmsAutofillListening = false;
      });

      if (smsCode != null && smsCode.isNotEmpty) {
        debugPrint('✅ [CUSTOMER OTP] SMS code received: $smsCode');

        _otpController.text = smsCode;

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          debugPrint('🔐 [CUSTOMER OTP] Auto-verifying OTP from SMS...');
          verifyOtp();
        }
      }
    } catch (e) {
      debugPrint('❌ [CUSTOMER OTP] Error listening for SMS: $e');
      if (mounted && generation == _smsListenGeneration) {
        setState(() {
          _isSmsAutofillListening = false;
        });
      }
    }
  }



  @override
  void dispose() {
    _autoVerifiedSub?.cancel();
    _timer?.cancel();
    _resendSecondsNotifier.dispose();
    _smsAutofillService.cancelListening();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locn = AppLocalizations.of(context);
    if (locn == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.bgBlueTint,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.bgWhite,

        leading: IconButton(
          iconSize: 18,
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: Text(
          locn.enterOtp,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: locn.otphasbeensentto,
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 14,
                              ),
                              children: [
                                WidgetSpan(
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      " ${widget.phoneNumber ?? ''} ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 6 OTP Boxes
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Pinput(
                                length: 6,
                                controller: _otpController,
                                focusNode: _focusNode,
                                // Keyboard up on open, so iOS can offer the
                                // code from Messages without a tap first.
                                autofocus: true,
                                defaultPinTheme: PinTheme(
                                  width: 45,
                                  height: 60,
                                  textStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                focusedPinTheme: PinTheme(
                                  width: 45,
                                  height: 60,
                                  textStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isSmsAutofillListening ? AppColors.green : AppColors.secondary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onCompleted: (pin) {
                                  FocusScope.of(context).unfocus();
                                  verifyOtp();
                                },
                              ),
                            ),
                            if (_isSmsAutofillListening)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppColors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      locn.listeningForSms,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      ValueListenableBuilder<int>(
                        valueListenable: _resendSecondsNotifier,
                        builder: (context, remainingTime, child) {
                          int minutes = remainingTime ~/ 60;
                          int seconds = remainingTime % 60;
                          String formattedTime =
                              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                remainingTime > 0
                                    ? '${locn.resendOTPin} $formattedTime ${locn.sText}'
                                    : locn.didntreciveCode,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              if (remainingTime <= 0) ...[
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: isResendingOtp ? null : resendOTP,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: isResendingOtp
                                      ? Loader(color: AppColors.green, size: 16)
                                          : Text(
                                              locn.resend,
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: AppColors.primary
                                .withOpacity(0.7),
                          ),
                          child: isLoading
                              ? Loader(color: Colors.white, size: 24)
                              : Text(
                                  locn.verifyOtp,
                                  style: TextStyle(
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
      backgroundColor: AppColors.bgBlueTint,
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
              style: TextStyle(
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
              style: TextStyle(
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
                      style: TextStyle(
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
              style: TextStyle(
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
