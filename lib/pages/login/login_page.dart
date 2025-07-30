import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/login/otp.dart';
import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/styles/app_images.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool isLoading = false;
  bool checked = true;
  int? _resendToken;
  bool isCheckUserEnableTwoStepVerification = false;
  String? customerLastUid;

  Future sentOTP() async {
    if (_phoneController.text.trim().length < 9) {
      showSnackBar(
        AppLocalizations.of(context)?.pleaseEnterAValidPhoneNumber ??
            'Please enter a valid phone number',
        context,
        backgroundColor: AppColors.yellow,
      );
      return;
    }

    await AuthServices().sendOTP(
      context,
      forceResendingToken: _resendToken,
      phoneNumber: _phoneController.text.trim(),
      onCodeSent: (String verificationId, {int? resendToken}) {
        if (mounted) {
          setState(() {
            _resendToken = resendToken;
            isLoading = false;
          });
        }
        showSnackBar(
          AppLocalizations.of(context)?.sendingOTP ?? 'Sending OTP...',
          backgroundColor: AppColors.primary,
          context,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpPage(
              phoneNumber: AuthServices.phoneNumber ?? '',
              verificationId: verificationId,
            ),
          ),
        );
      },
      onError: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        showSnackBar(
          e.message ?? 'An error occurred',
          context,
          backgroundColor: AppColors.red,
        );
      },
    );
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
                  children: [
                    Stack(
                      alignment: Alignment.topCenter,
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
                        Image.asset(
                          AppImages.workerArtLogin,
                          height: 286,
                          width: 290,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                    Text(
                      AppLocalizations.of(context)?.appLoginCaption ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Center(
                      child: LanguageSelector(
                        currentLanguageCode: state.locale.languageCode,
                      ),
                    ),
                    const SizedBox(height: 23),
                    Text(
                      AppLocalizations.of(context)?.mobileNumber ?? '',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(left: 22, right: 22),
                      child: TextFormField(
                        controller: _phoneController,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.number,
                        inputFormatters: [LengthLimitingTextInputFormatter(9)],
                        style: GoogleFonts.dmSans(
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
                              Text(
                                "+966",
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          // suffixIcon:
                          //     ?
                          //     : null,
                        ),
                        onFieldSubmitted: (_) {
                          if (!isLoading) {
                            // sentOTP();
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 6),
                    CheckboxListTile.adaptive(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.all(0),
                      title: Text(
                        AppLocalizations.of(context)?.rememberMe ?? '',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      side: BorderSide(color: Colors.white),
                      activeColor: Colors.blue,
                      checkColor: Colors.white,
                      value: checked,
                      onChanged: (value) async {
                        setState(() {
                          checked = value!;
                        });
                        // await sharedHelper().setRememberMe(checked);
                        // if (!checked) {
                        //   await sharedHelper().clearPhoneNumber();
                        // }
                      },
                    ),
                    // if (customerLastUid != null && isCheckUserEnableTwoStepVerification)
                    //   Row(
                    //     mainAxisAlignment: MainAxisAlignment.center,
                    //     children: [
                    //       GestureDetector(
                    //         onTap: () => _byPassUsingBioAuth(context),
                    //         child: Image.asset(
                    //           'assets/images/fingerPrint.png',
                    //           height: 54,
                    //           width: 54,
                    //           color: Colors.white,
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        width: double.maxFinite,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    if (mounted) {
                                      setState(() {
                                        isLoading = true;
                                      });
                                    }
                                    await sentOTP();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            disabledBackgroundColor: AppColors.secondary
                                .withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isLoading
                              ? Loader(size: 20, color: Colors.white)
                              : Text(
                                  AppLocalizations.of(context)?.continueText ??
                                      '',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // sharedHelper().setUserStatus(true);
                          // Navigator.pushAndRemoveUntil(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) =>
                          //         AppMain(isGuestUser: true, initialTabIndex: 0),
                          //   ),
                          //   (route) => false,
                          // );
                        },
                        child: Text(
                          AppLocalizations.of(context)?.signUpLater ?? '',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                            text:
                                AppLocalizations.of(
                                  context,
                                )?.byContinuingYouAgreeToOur ??
                                '',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                          TextSpan(
                            text:
                                AppLocalizations.of(
                                  context,
                                )?.termsOfUseAndPrivacyPolicy ??
                                '',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
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
