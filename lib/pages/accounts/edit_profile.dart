import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/login/otp.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfilePage extends StatefulWidget {
  final CustomerModel customer;
  const EditProfilePage({super.key, required this.customer});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool isLoading = false;
  bool isUpdating = false;
  List<LocationModel> _locations = [];
  bool isPhoneNumberUpdated = false;
  int? _resendToken;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityNameController = TextEditingController();
  final TextEditingController neighborhoodController = TextEditingController();
  final TextEditingController districtNameController = TextEditingController();

  @override
  void initState() {
    _fetchLocations();
    _fillOut();
    super.initState();
  }

  void _fillOut() {
    try {
      nameController.text = widget.customer.name ?? '';
      emailController.text = widget.customer.email ?? '';
      phoneController.text = widget.customer.phone ?? '';
      neighborhoodController.text = widget.customer.neighbourhood ?? '';
      cityNameController.text = widget.customer.cityName ?? '';
      districtNameController.text = widget.customer.districtName ?? '';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.errorFillingProfile ??
                'Error filling out profile',
          ),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _fetchLocations() async {
    try {
      _locations = await AppServices.fetchLocations();
    } catch (e) {
      debugPrint('❌ Error fetching locations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.errorFetchingLocations ??
                'Error fetching locations',
          ),
          backgroundColor: AppColors.red,
        ),
      );
      _locations = [];
    }
  }

  void _updateProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedCustomer = widget.customer.copyWith(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        cityName: cityNameController.text.trim(),
        districtName: districtNameController.text.trim(),
        neighbourhood: neighborhoodController.text.trim(),
        updatedAt: Timestamp.now(),
      );

      context.read<AccountBloc>().add(
        UpdateCustomerProfile(
          customerData: updatedCustomer,
          previousCustomerData: widget.customer,
        ),
      );
    }
  }

  void selectLocationBottomSheet() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final safePaddings = MediaQuery.of(context).padding;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.selectDistrict ??
                        'Select District',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _locations.length,
                padding: EdgeInsets.only(bottom: safePaddings.bottom + 16),
                itemBuilder: (context, index) {
                  final location = _locations[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.apartment_rounded,
                      color: AppColors.grey2,
                    ),
                    title: Text(
                      AppLocalizations.of(context)?.localeName == "ar"
                          ? location.name_ar ?? ''
                          : location.name ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      districtNameController.text = location.name ?? '';
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.dmSans(
              color: backgroundColor == AppColors.yellow
                  ? Colors.grey.shade800
                  : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: backgroundColor ?? AppColors.yellow,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;
    if (!phoneNumber.startsWith('05')) return false;
    if (phoneNumber.length < 10 || phoneNumber.length > 10) return false;
    return true;
  }

  void _updatePhoneNumber() async {
    if (!_isValidPhoneNumber(phoneController.text)) {
      _showSnackBar(
        AppLocalizations.of(context)?.pleaseEnterAValidPhoneNumber ??
            'Invalid number',
        backgroundColor: AppColors.red,
      );
      return;
    }

    bool isNumberAlreadyExists =
        await AppServices.checkCustomerPhoneNumberAlredyExist(
          phoneController.text,
        );
    if (phoneController.text != widget.customer.phone) {
      if (mounted) setState(() => isLoading = true);
      if (isNumberAlreadyExists) {
        if (mounted) setState(() => isLoading = false);
        _showSnackBar(
          AppLocalizations.of(context)?.phoneNumberAlreadyExists ?? '',
          backgroundColor: AppColors.yellow,
        );
        return;
      }
      if (phoneController.text.startsWith('05')) {
        if (mounted) setState(() => isPhoneNumberUpdated = true);
        // Remove the leading '0' and add '+966' before the rest
        final formattedPhone = '+966${phoneController.text.substring(1)}';
        debugPrint(formattedPhone);
        await AuthServices().sendOTP(
          context,
          phoneNumber: formattedPhone,
          forceResendingToken: _resendToken,
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
                  phoneNumber: phoneController.text,
                  verificationId: verificationId,
                  isFromProfile: true,
                ),
              ),
            );
          },
          onError: (FirebaseAuthException e) {
            if (mounted) setState(() => isLoading = false);
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
              case 'session-expired':
                errorMessage =
                    AppLocalizations.of(context)?.otpExpired ??
                    'OTP expired. Please request a new OTP.';
                break;
              case 'invalid-phone-number':
                errorMessage =
                    AppLocalizations.of(
                      context,
                    )?.pleaseEnterAValidPhoneNumber ??
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
                    AppLocalizations.of(context)?.somethingWentWrongTryAgain ??
                    'Something went wrong. Please try again.';
            }

            _showSnackBar(errorMessage, backgroundColor: AppColors.red);
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.pleaseAddCountryCode ??
                  'Please enter a valid phone number starting with 05',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) setState(() => isLoading = false);
      _showSnackBar(
        AppLocalizations.of(context)?.phoneNumberAlreadyUpdated ?? '',
        backgroundColor: AppColors.yellow,
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final locale = AppLocalizations.of(context);

    return BlocListener<AccountBloc, AccountState>(
      listener: (context, state) {
        if (state is UpdateCustomerProfileSucess) {
          _showSnackBar(
            AppLocalizations.of(context)?.profileUpdatedSuccessfully ??
                'Profile updated successfully',
            backgroundColor: AppColors.green,
          );
          if (mounted) {
            Navigator.pop(context);
          }
        }
        if (state is UpdateCustomerProfileError) {
          _showSnackBar(state.error, backgroundColor: AppColors.red);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(locale?.profileManagement ?? ''),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: safePadding.bottom + 16,
            ),
            children: [
              TextFormWidget(
                controller: nameController,
                label: locale?.yourName ?? '',
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return locale?.nameIsRequired ?? '';
                  } else if (value.length < 3) {
                    return locale?.enterAValidName ?? '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormWidget(
                controller: emailController,
                label: locale?.emailAddress ?? '',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return locale?.emailIsRequired ?? '';
                  }

                  final email = value.trim();

                  if (email.length < 5) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  if (!email.contains('@') || !email.contains('.')) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    caseSensitive: false,
                  );

                  if (!emailRegex.hasMatch(email)) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  if (email.contains('..')) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  if (email.startsWith('.') ||
                      email.startsWith('-') ||
                      email.endsWith('.') ||
                      email.endsWith('-')) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  final parts = email.split('@');
                  if (parts.length != 2) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  final localPart = parts[0];
                  final domainPart = parts[1];

                  if (localPart.isEmpty || localPart.length > 64) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  if (domainPart.isEmpty || domainPart.length > 255) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  if (!domainPart.contains('.')) {
                    return locale?.enterAValidEmail ?? '';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormWidget(
                controller: phoneController,
                label: locale?.phoneNumber ?? '',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*')),
                  LengthLimitingTextInputFormatter(10),
                ],
                suffixIcon: TextButton(
                  onPressed: _updatePhoneNumber,
                  child: Text(locale?.update ?? ''),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return locale?.pleaseEnterAValidPhoneNumber ?? '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormWidget(
                controller: neighborhoodController,
                label: locale?.neighbourhood ?? '',
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return locale?.neighbourhoodIsRequired ?? '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormWidget(
                controller: cityNameController,
                label: locale?.city ?? '',
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return locale?.cityNameIsRequired ?? '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormWidget(
                controller: districtNameController,
                label: locale?.districtName ?? '',
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                onTap: selectLocationBottomSheet,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return locale?.districtNameIsRequired ?? '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              BlocBuilder<AccountBloc, AccountState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.maxFinite,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: state is UpdateCustomerProfileLoading
                          ? () {}
                          : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: state is UpdateCustomerProfileLoading
                          ? Loader(size: 20, color: Colors.white)
                          : Text(
                              locale?.update ?? '',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    districtNameController.dispose();
    super.dispose();
  }
}
