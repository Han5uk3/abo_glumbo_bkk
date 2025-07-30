import 'dart:async';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class OtpPage extends StatefulWidget {
  final String? phoneNumber;
  final String? verificationId;
  const OtpPage({super.key, this.phoneNumber, this.verificationId});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  bool isLoading = false;
  bool isResendingOtp = false;
  bool _isMigratingCustomerData = false;
  int resendSeconds = 60;
  Timer? _timer;
  final _formKey = GlobalKey<FormState>();
  final otpController = TextEditingController();
  String? _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    startTimer();
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

  void resendOTP() {
    if (resendSeconds > 0) return;

    setState(() {
      isResendingOtp = true;
    });

    AuthServices().resendOTP(
      phoneNumber: widget.phoneNumber ?? '',
      resendToken: _resendToken,
      onCodeSent: (verificationId, {int? resendToken}) {
        setState(() {
          isResendingOtp = false;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP resent successfully'),
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
      },
      onError: (error) {
        setState(() {
          isResendingOtp = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Failed to resend OTP'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }

  void verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

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

      await AuthServices()
          .checkUser(userCredential: userCredential, context: context)
          .then((_) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        String errorMessage = 'Invalid OTP. Please try again.';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'invalid-verification-code':
              errorMessage = 'Invalid OTP. Please enter the correct code.';
              break;
            case 'session-expired':
              errorMessage = 'OTP has expired. Please request a new one.';
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

  @override
  void dispose() {
    _timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locn = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 90,
        leading: TextButton.icon(
          onPressed: _isMigratingCustomerData
              ? null
              : () => Navigator.pop(context),
          label: Text(
            AppLocalizations.of(context)?.back ?? '',
            style: GoogleFonts.dmSans(
              color: _isMigratingCustomerData
                  ? Colors.grey
                  : AppColors.secondary,
              fontSize: 16,
            ),
          ),
          icon: Icon(
            Icons.arrow_back_ios,
            color: _isMigratingCustomerData ? Colors.grey : Colors.black87,
          ),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isMigratingCustomerData,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  locn.otpVerification,
                  style: GoogleFonts.dmSans(
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
                          style: GoogleFonts.dmSans(
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
                                  style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.green),
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
                      style: GoogleFonts.dmSans(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    if (_remainingTime <= 0) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: isResendingOtp ? null : resendOTP,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                style: GoogleFonts.dmSans(
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
                      disabledBackgroundColor: AppColors.secondary.withOpacity(
                        0.7,
                      ),
                    ),
                    child: isLoading
                        ? Loader(color: Colors.white, size: 24)
                        : Text(
                            locn.verifyOtp,
                            style: GoogleFonts.dmSans(
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
      ),
    );
  }
}
