import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/login/otp.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/auth_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class EditProfilePage extends StatefulWidget {
  final CustomerModel? customer;
  const EditProfilePage({super.key, this.customer});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool isLoading = false;
  bool isPageLoading = true;

  bool isPhoneNumberUpdated = false;
  bool _isUpdatingPhone = false;
  int? _resendToken;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ✅ Load data
  Future<void> _loadData() async {
    try {
      // 1. Check if customer data exists
      if (widget.customer == null) {
        throw Exception('Customer data is null');
      }

      // 2. Fill text fields
      _fillOut();

    } catch (e) {
      if (kDebugMode) {
        print('Error loading data: $e');
      }
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context)?.errorFillingProfile ??
              'Error loading profile data',
          backgroundColor: AppColors.red,
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          isPageLoading = false;
        });
      }
    }
  }

  void _fillOut() {
    try {
      if (widget.customer == null) {
        return;
      }
      nameController.text = widget.customer!.name ?? '';
      emailController.text = widget.customer!.email ?? '';
      phoneController.text = widget.customer!.phone ?? '';
    } catch (e) {
      _showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ??
            'Error filling out profile',
        backgroundColor: AppColors.red,
      );
    }
  }

  void _updateProfile() {
    if (widget.customer == null) {
      _showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ??
            'Customer data not available',
        backgroundColor: AppColors.red,
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      final updatedCustomer = widget.customer!.copyWith(
        role: "customer",
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        updatedAt: Timestamp.now(),
      );

      context.read<AccountBloc>().add(
        UpdateCustomerProfile(
          customerData: updatedCustomer,
          previousCustomerData: widget.customer!,
        ),
      );
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: DMSansFont.textStyle(
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
    if (phoneNumber.length != 10) return false;
    return true;
  }

  void _updatePhoneNumber() async {
    // Check if customer data exists
    if (widget.customer == null) {
      _showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ??
            'Customer data not available',
        backgroundColor: AppColors.red,
      );
      return;
    }

    // Prevent multiple clicks
    if (_isUpdatingPhone) return;

    if (!_isValidPhoneNumber(phoneController.text)) {
      _showSnackBar(
        AppLocalizations.of(context)?.pleaseEnterAValidPhoneNumber ??
            'Invalid number',
        backgroundColor: AppColors.red,
      );
      return;
    }

    if (phoneController.text != widget.customer?.phone) {
      if (mounted) {
        setState(() {
          isLoading = true;
          _isUpdatingPhone = true;
        });
      }

      bool isNumberAlreadyExists =
          await AppServices.checkCustomerPhoneNumberAlredyExist(
            phoneController.text,
            excludeUid: widget.customer!.uid,
          );

      if (isNumberAlreadyExists) {
        if (mounted) {
          setState(() {
            isLoading = false;
            _isUpdatingPhone = false;
          });
        }
        _showSnackBar(
          AppLocalizations.of(context)?.phoneNumberAlreadyExists ?? '',
          backgroundColor: AppColors.yellow,
        );
        return;
      }

      if (phoneController.text.startsWith('05')) {
        if (mounted) setState(() => isPhoneNumberUpdated = true);
        final formattedPhone = '+966${phoneController.text.substring(1)}';

        await AuthServices().sendOTP(
          context,
          phoneNumber: formattedPhone,
          forceResendingToken: _resendToken,
          onCodeSent: (String verificationId, {int? resendToken}) {
            if (mounted) {
              setState(() {
                _resendToken = resendToken;
                isLoading = false;
                _isUpdatingPhone = false;
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
            if (mounted) {
              setState(() {
                isLoading = false;
                _isUpdatingPhone = false;
              });
            }
            String errorMessage;
            switch (e.code) {
              case 'too-many-requests':
                errorMessage =
                    AppLocalizations.of(context)?.tooManyAttempts ??
                    'Too many attempts. Please wait and try again.';
                break;
              case 'invalid-phone-number':
                errorMessage =
                    AppLocalizations.of(
                      context,
                    )?.pleaseEnterAValidPhoneNumber ??
                    'Please enter a valid phone number';
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
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
          _isUpdatingPhone = false;
        });
      }
      _showSnackBar(
        AppLocalizations.of(context)?.phoneNumberAlreadyUpdated ?? '',
        backgroundColor: AppColors.yellow,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final locale = AppLocalizations.of(context);

    // Show error and navigate back if customer is null
    if (widget.customer == null && !isPageLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSnackBar(
            locale?.errorFillingProfile ?? 'Customer data not available',
            backgroundColor: AppColors.red,
          );
          Navigator.pop(context);
        }
      });
    }

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
          backgroundColor: AppColors.bgWhite,
          title: Text(
            locale?.profileManagement ?? 'Profile Management',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: true,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: Colors.black, // Explicitly set back arrow color
            ),
          ),
        ),
        body: isPageLoading
            ? Center(child: Loader(color: AppColors.secondary, size: 40))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: safePadding.bottom + 16,
                  ),
                  children: [
                    const SizedBox(height: 16),

                    // Name Field
                    TextFormWidget(
                      controller: nameController,
                      label: locale?.yourName ?? 'Your Name',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return locale?.nameIsRequired ?? 'Name is required';
                        } else if (value.length < 3) {
                          return locale?.enterAValidName ??
                              'Enter a valid name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phone Field
                    TextFormWidget(
                      controller: phoneController,
                      label: locale?.phoneNumber ?? 'Phone Number',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      suffixIcon: _isUpdatingPhone
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: _isUpdatingPhone
                                  ? null
                                  : _updatePhoneNumber,
                              child: Text(locale?.update ?? 'Save'),
                            ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return locale?.pleaseEnterAValidPhoneNumber ?? '';
                        }
                        return null;
                      },
                    ),
                    // Email Field
                    TextFormWidget(
                      controller: emailController,
                      label: locale?.emailAddress ?? 'Email Address',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (value != null && value.isNotEmpty) {
                          if (!emailRegex.hasMatch(value)) {
                            return locale?.enterAValidEmail ??
                                'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      AppLocalizations.of(context)?.phoneNumberUpdateInfo ??
                          'To update phone number, please click the "Update" button.',
                      style: DMSansFont.textStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Update Button
                    BlocBuilder<AccountBloc, AccountState>(
                      builder: (context, state) {
                        return SizedBox(
                          width: double.maxFinite,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: state is UpdateCustomerProfileLoading
                                ? null
                                : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: state is UpdateCustomerProfileLoading
                                ? Loader(size: 20, color: Colors.white)
                                : Text(
                                    locale?.update ?? 'Update',
                                    style: DMSansFont.textStyle(
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
    super.dispose();
  }
}
