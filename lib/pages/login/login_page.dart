import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/helpers/country_code_detector.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/privacy_policy_page.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/terms_and_conditions_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/otp.dart';
import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/error_codes.dart' as local_auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:material_symbols_icons/symbols.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isRememberMeChecked = false;
  int? _resendToken;
  bool isCheckUserEnableTwoStepVerification = false;
  String? customerLastUid;
  bool isUserLogout = false;
  bool _isFaceId = false;
  // String? _detectedCountryCode;
  // String? _displayCountryCode;
  // String? _detectedFlag;

  @override
  void initState() {
    customerLastUid =
        LocalStoreHelper.getUID() ?? LocalStoreHelper.getLastValidUID();
    isCheckUserEnableTwoStepVerification =
        LocalStoreHelper.getBiometricAuthEnabled(customerLastUid ?? '');
    isUserLogout = LocalStoreHelper.getLogoutStatus();
    _isRememberMeChecked = LocalStoreHelper.getRememberMe();
    if (_isRememberMeChecked) {
      _phoneController.text = LocalStoreHelper.getPhoneNumber() ?? '';
    } else {
      _phoneController.clear();
    }
    super.initState();

    // Initialize notifications after splash screen
    Future.delayed(Duration.zero, () async {
      await NotificationServices.initializeNotifications();
      NotificationServices.setupFCMListeners();
      await NotificationServices.checkForInitialMessage();
    });

    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final auth = LocalAuthentication();
      final available = await auth.getAvailableBiometrics();
      if (available.contains(BiometricType.face)) {
        if (mounted) {
          setState(() {
            _isFaceId = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_isLoading) return;
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.length < 9) {
      _showSnackBar(
        AppLocalizations.of(context)?.pleaseEnterAValidPhoneNumber ??
            'Please enter a valid phone number',
        AppColors.yellow,
      );
      return;
    }

    // Format phone number with country code
    final formattedPhoneNumber = CountryCodeDetector.formatPhoneNumber(
      phoneNumber,
      countryCode: "SA",
    );
    debugPrint('📱 [CUSTOMER LOGIN] Original: $phoneNumber');
    debugPrint('📱 [CUSTOMER LOGIN] Formatted: $formattedPhoneNumber');

    setState(() {
      _isLoading = true;
    });

    if (_isRememberMeChecked &&
        (phoneNumber != LocalStoreHelper.getPhoneNumber())) {
      LocalStoreHelper.putPhoneNumber(phoneNumber);
    } else if (!_isRememberMeChecked) {
      LocalStoreHelper.clearPhoneNumber();
    }

    debugPrint(
      '🚀 [LOGIN PAGE] Initiating OTP send for: $formattedPhoneNumber',
    );
    await AuthServices().sendOTP(
      context,
      forceResendingToken: _resendToken,
      phoneNumber: formattedPhoneNumber,
      onCodeSent: (String verificationId, {int? resendToken}) {
        debugPrint('🎯 [LOGIN PAGE] onCodeSent callback triggered');
        debugPrint('🆔 [LOGIN PAGE] Verification ID: $verificationId');
        if (mounted) {
          debugPrint(
            '📱 [LOGIN PAGE] Widget mounted, updating UI and navigating to OTP page',
          );
          setState(() {
            _resendToken = resendToken;
            _isLoading = false;
          });
          _showSnackBar(
            AppLocalizations.of(context)?.sendingOTP ?? 'Sending OTP...',
            AppColors.primary,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpPage(
                phoneNumber: AuthServices.phoneNumber ?? formattedPhoneNumber,
                verificationId: verificationId,
              ),
            ),
          ).then(
            (value) =>
                debugPrint('✅ [LOGIN PAGE] Navigation to OtpPage complete'),
          );
        } else {
          debugPrint(
            '⚠️ [LOGIN PAGE] onCodeSent received but widget is unmounted',
          );
          // Still set loading false globally if possible or shared state
        }
      },
      onError: (FirebaseAuthException e) {
        debugPrint('❌ [LOGIN PAGE] onError callback triggered');
        debugPrint('❌ [LOGIN PAGE] Error: ${e.code} - ${e.message}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          String errorMessage;
          switch (e.code) {
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
            case 'invalid-phone-number':
              errorMessage =
                  AppLocalizations.of(context)?.pleaseEnterAValidPhoneNumber ??
                  'Please enter a valid phone number';
              break;
            case 'internal-error':
              errorMessage =
                  AppLocalizations.of(context)?.internalError ??
                  'An internal error occurred. Please try again later.';
              break;
            default:
              errorMessage =
                  e.message ??
                  (AppLocalizations.of(context)?.anErrorOccurred ??
                      'An error occurred');
          }

          _showSnackBar(errorMessage, AppColors.red);
        }
      },
    );
  }

  Future<void> _signUpLater() async {
    try {
      setState(() => _isLoading = true);
      await AuthServices().signInAsGuest(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          '${AppLocalizations.of(context)?.unexpectedErrorOccurred ?? (AppLocalizations.of(context)?.error ?? 'Error')}: ${e.toString()}',
          AppColors.red,
        );
      }
    }
  }

  void _byPassUsingBioAuth(BuildContext context) async {
    final auth = LocalAuthentication();
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.biometricNotSupported ??
                  'Biometric authentication is not supported on this device.',
            ),
          ),
        );
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason:
            AppLocalizations.of(context)?.pleaseAuthenticateToContinue ??
            'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }
        await LocalStoreHelper.putGuestUser(false);
        if (customerLastUid != null) {
          await LocalStoreHelper.putUID(customerLastUid!);
          await LocalStoreHelper.setBiometricAuthEnabled(
            true,
            customerLastUid!,
          );
        }
        await LocalStoreHelper.putlogoutStatus(false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => Home(byPassedUid: customerLastUid),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.authenticationFailed ??
                  '❌ Authentication failed',
            ),
          ),
        );
      }
    } on PlatformException catch (exception) {
      String message = '';
      switch (exception.code) {
        case local_auth_error.notAvailable:
        case local_auth_error.passcodeNotSet:
        case local_auth_error.notEnrolled:
          message =
              AppLocalizations.of(context)?.biometricNotAvailable ??
              '❌ Biometric authentication is not available on this device.';
          break;
        case local_auth_error.lockedOut:
        case local_auth_error.permanentlyLockedOut:
          message =
              AppLocalizations.of(context)?.biometricTemporarilyLocked ??
              '🔒 Too many failed attempts. Biometric is temporarily locked.';
          break;
        default:
          if (exception.message?.toLowerCase().contains('canceled') == true) {
            return;
          }
          final errorPrefix =
              AppLocalizations.of(context)?.biometricError ??
              '❌ Biometric error';
          final unknownError =
              AppLocalizations.of(context)?.unknownError ?? 'Unknown error';
          message = '$errorPrefix: ${exception.message ?? unknownError}';
      }

      if (message.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.unexpectedErrorOccurred ??
                '❌ Unexpected error occurred',
          ),
        ),
      );
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    showSnackBar(message, context, backgroundColor: backgroundColor);
  }

  Future<void> _onLoginPressed() async {
    if (_formKey.currentState!.validate()) {
      await _sendOTP();
    }
  }

  void _onRememberMeChanged(bool? value) {
    LocalStoreHelper.putRememberMe(value ?? false);
    setState(() {
      _isRememberMeChecked = value ?? false;
      if (_isRememberMeChecked) {
        LocalStoreHelper.clearPhoneNumber();
        LocalStoreHelper.putPhoneNumber(_phoneController.text.trim());
      } else {
        LocalStoreHelper.clearPhoneNumber();
      }
    });
  }

  Widget _buildPhoneInputField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇸🇦', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  "+966",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 24,
                width: 1,
                color: Colors.black.withOpacity(0.1),
              ),
              const SizedBox(width: 12),
            ],
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '5XXXXXXXX',
                hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _onLoginPressed();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _isRememberMeChecked,
            onChanged: _onRememberMeChanged,
            activeColor: AppColors.primary,
            side: BorderSide(color: Colors.black.withOpacity(0.4), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _onRememberMeChanged(!_isRememberMeChecked),
          child: Text(
            AppLocalizations.of(context)?.rememberMe ?? 'Remember me',
            style: TextStyle(
              color: Colors.black.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFingerprintAuth() {
    return Center(
      child: GestureDetector(
        onTap: () => _byPassUsingBioAuth(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isFaceId
                  ? Icon(
                      Symbols
                          .familiar_face_and_zone, // Using familiar face and zone icon for FaceID
                      size: 60,
                      color: AppColors.primary,
                    )
                  : Image.asset(
                      'assets/images/fingerPrint.png',
                      height: 60,
                      width: 60,
                      color: AppColors.primary,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,

      // padding: const EdgeInsets.only(top: 8.0),
      child: SizedBox(
        width: double.maxFinite,
        // height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _onLoginPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const Loader(size: 20, color: Colors.white)
              : Text(
                  AppLocalizations.of(context)?.continueText ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSignUpLaterButton() {
    return Center(
      child: TextButton(
        onPressed: _signUpLater,
        child: Text(
          AppLocalizations.of(context)?.signUpLater ?? '',
          style: TextStyle(
            color: Colors.black.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsAndPrivacyText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text:
                  "${AppLocalizations.of(context)?.byContinuingYouAgreeToOur ?? ''}\n ",
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
            TextSpan(
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          TermsAndConditionsPage(isFromLogin: true),
                    ),
                  );
                },
              text: AppLocalizations.of(context)?.termsOfUse ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(
              text: " ${AppLocalizations.of(context)!.and} ",
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
            TextSpan(
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PrivacyPolicyPage(),
                    ),
                  );
                },
              text: AppLocalizations.of(context)?.privacyPolicy ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.bgBlueTint,

          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Image Container - Fixed size 40x40
                  Container(
                    height: MediaQuery.of(context).size.height * 0.27,
                    color: AppColors.primary,
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      children: [
                        SizedBox(height: 32),
                        SizedBox(
                          height: 181,
                          width: 182,
                          // margin: EdgeInsets.only(bottom: 20), // Add some spacing
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit
                                .contain, // Changed from fill to contain for better quality
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Container with Border Radius
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgBlueTint,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(60),
                        topRight: Radius.circular(60),
                      ),
                    ),
                    // Remove fixed height to let content determine height
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height *
                          0.63, // Minimum height
                    ),

                    // alignment: Alignment.center,
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.login,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const SizedBox(height: 20),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.of(context)?.mobileNumber ??
                                      '',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(.7),
                                    fontSize: 14,
                                  ),
                                ),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: LanguageSelectorCard(
                                    isInLoginPage: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildPhoneInputField(),
                            const SizedBox(height: 10),
                            _buildRememberMeCheckbox(),
                            const SizedBox(height: 20),
                            _buildLoginButton(),
                            const SizedBox(height: 10),
                            _buildSignUpLaterButton(),
                            const SizedBox(height: 20),
                            _buildTermsAndPrivacyText(),
                            const SizedBox(height: 20),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.center,
                            //   children: [
                            //     Text(
                            //       "OR",
                            //       style: TextStyle(color: Color(0xff757575)),
                            //     ),
                            //   ],
                            // ),
                            // const SizedBox(height: 20),

                            // _buildSignUpLaterButton(),
                            // eButton(
                            //   height: 54,
                            //   icon: FaIcon(
                            //     FontAwesomeIcons.google,
                            //     color: Colors.red,
                            //     size: 20,
                            //   ),
                            //   width: MediaQuery.of(context).size.width,
                            //   backgroundColor: Colors.white,
                            //   text:
                            //       "Continue with Google", // Fixed typo: "Contiue" -> "Continue"
                            //   onPressed: () {},
                            //   textColor: Colors.black,
                            //   context: context,
                            // ),
                            // const SizedBox(height: 10),
                            // // _buildSignUpLaterButton(),
                            // eButton(
                            //   height: 54,
                            //   icon: FaIcon(
                            //     FontAwesomeIcons.apple,
                            //     color:
                            //         Colors.black, // Changed to black for Apple icon
                            //     size: 20,
                            //   ),
                            //   width: MediaQuery.of(context).size.width,
                            //   backgroundColor: Colors.white,
                            //   text: "Continue with Apple", // Fixed typo
                            //   onPressed: () {},
                            //   textColor: Colors.black,
                            //   context: context,
                            // ),
                            if (isCheckUserEnableTwoStepVerification &&
                                customerLastUid != null &&
                                customerLastUid!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey.withOpacity(
                                        0.5,
                                      ), // Changed to grey for white background
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context)?.or ?? 'OR',
                                      style: TextStyle(
                                        color: Colors.grey.withOpacity(
                                          0.7,
                                        ), // Changed to grey
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey.withOpacity(
                                        0.5,
                                      ), // Changed to grey
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildFingerprintAuth(),
                            ],
                            const SizedBox(height: 60),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
