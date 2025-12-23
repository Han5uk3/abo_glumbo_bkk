import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/privacy_policy_page.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/terms_and_conditions_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/otp.dart';
import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/styles/app_images.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:local_auth/error_codes.dart' as local_auth_error;
import 'package:local_auth/local_auth.dart';

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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.length < 9) {
      _showSnackBar(
        AppLocalizations.of(context)?.pleaseEnterAValidPhoneNumber ??
            'Please enter a valid phone number',
        AppColors.yellow,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_isRememberMeChecked &&
        (phoneNumber != LocalStoreHelper.getPhoneNumber())) {
      LocalStoreHelper.putPhoneNumber(phoneNumber);
    } else if (!_isRememberMeChecked) {
      LocalStoreHelper.clearPhoneNumber();
    }

    await AuthServices().sendOTP(
      context,
      forceResendingToken: _resendToken,
      phoneNumber: phoneNumber,
      onCodeSent: (String verificationId, {int? resendToken}) {
        if (mounted) {
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
                phoneNumber: AuthServices.phoneNumber ?? phoneNumber,
                verificationId: verificationId,
              ),
            ),
          );
        }
      },
      onError: (FirebaseAuthException e) {
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
              errorMessage = e.message ?? 'An error occurred';
          }

          _showSnackBar(errorMessage, AppColors.red);
        }
      },
    );
  }

  Future<void> _signUpLater() async {
    try {
      final currentUid = LocalStoreHelper.getUID();
      final isBiometricEnabled = currentUid != null
          ? LocalStoreHelper.getBiometricAuthEnabled(currentUid)
          : false;

      if (!isBiometricEnabled) {
        await LocalStoreHelper.clearUID();
      }
      await LocalStoreHelper.putGuestUser(true);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Home(initialIndex: 0)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error occurred while setting guest mode: ${e.toString()}',
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
          message =
              '❌ Biometric error: ${exception.message ?? 'Unknown error'}';
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

  Widget _buildHeaderImage() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              child: Container(
                height: 305,
                width: 256,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
            Container(
              height: 295,
              width: 278,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: SizedBox(
                height: 285,
                width: 290,
                child: Image.asset(
                  AppImages.loginImage,

                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.only(left: 22, right: 22),
      child: TextFormField(
        controller: _phoneController,
        textInputAction: TextInputAction.done,
        keyboardType: TextInputType.number,
        inputFormatters: [LengthLimitingTextInputFormatter(9)],
        style: DMSansFont.textStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  "+966",
                  style: DMSansFont.textStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        onFieldSubmitted: (_) {
          if (!_isLoading) {
            _onLoginPressed();
          }
        },
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Center(
      child: CheckboxListTile.adaptive(
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.all(0),
        title: Text(
          AppLocalizations.of(context)?.rememberMe ?? '',
          style: DMSansFont.textStyle(color: Colors.white, fontSize: 14),
        ),
        side: const BorderSide(color: Colors.white),
        activeColor: Colors.blue,
        checkColor: Colors.white,
        value: _isRememberMeChecked,
        onChanged: _onRememberMeChanged,
      ),
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
              Image.asset(
                'assets/images/fingerPrint.png',
                height: 60,
                width: 60,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SizedBox(
        width: double.maxFinite,
        height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _onLoginPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            disabledBackgroundColor: AppColors.secondary.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const Loader(size: 20, color: Colors.white)
              : Text(
                  AppLocalizations.of(context)?.continueText ?? '',
                  style: DMSansFont.textStyle(
                    color: Colors.white,
                    fontSize: 16,
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
          style: DMSansFont.textStyle(
            color: Colors.white,
            fontSize: 16,
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
                  "${AppLocalizations.of(context)?.byContinuingYouAgreeToOur ?? ''} ",
              style: DMSansFont.textStyle(fontSize: 11, color: Colors.white60),
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
              style: DMSansFont.textStyle(
                fontSize: 11,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(
              text: " ${AppLocalizations.of(context)!.and} ",
              style: DMSansFont.textStyle(fontSize: 11, color: Colors.white60),
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
              style: DMSansFont.textStyle(
                fontSize: 11,
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
  void initState() {
    customerLastUid = LocalStoreHelper.getUID();
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.primary,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildHeaderImage(),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        AppLocalizations.of(context)?.loginDescription ?? '',
                        textAlign: TextAlign.center,
                        style: DMSansFont.textStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: LanguageSelectorCard(isInLoginPage: true),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)?.mobileNumber ?? '',
                      style: DMSansFont.textStyle(
                        color: Colors.white.withOpacity(.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPhoneInputField(),
                    const SizedBox(height: 6),
                    _buildRememberMeCheckbox(),
                    const SizedBox(height: 10),
                    _buildLoginButton(),
                    const SizedBox(height: 10),
                    _buildSignUpLaterButton(),

                    if (isCheckUserEnableTwoStepVerification &&
                        customerLastUid != null &&
                        customerLastUid!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.white.withOpacity(0.5),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppLocalizations.of(context)?.or ?? 'OR',
                              style: DMSansFont.textStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.white.withOpacity(0.5),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFingerprintAuth(),
                    ],
                    const SizedBox(height: 20),
                    _buildTermsAndPrivacyText(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
