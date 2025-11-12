import 'dart:convert';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location_selection.dart'; // ✅ Add this
import 'package:abo_glumbo_bbk/models/user.dart';
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
  bool isLoadingLocations = true;
  bool isPhoneNumberUpdated = false;
  int? _resendToken;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // ✅ Location dropdowns (same as signup)
  List<Province> provinces = [];
  Province? selectedProvince;
  Governorate? selectedGovernorate;
  Neighborhood? selectedNeighborhood;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _fillOut();
  }

  // ✅ Load locations from JSON
  Future<void> _loadLocations() async {
    setState(() => isLoadingLocations = true);
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_locations.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);

      setState(() {
        provinces = jsonData.map((p) => Province.fromJson(p)).toList();
        isLoadingLocations = false;
      });

      // After loading, pre-select if data exists
      if (widget.customer.detailedLocation != null) {
        _preselectLocation(widget.customer.detailedLocation!);
      }
    } catch (e) {
      debugPrint('❌ Error loading locations: $e');
      setState(() => isLoadingLocations = false);
      _showSnackBar(
        AppLocalizations.of(context)?.errorFetchingLocations ??
            'Error fetching locations',
        backgroundColor: AppColors.red,
      );
    }
  }

  // ✅ Pre-select saved location
  void _preselectLocation(DetailedLocationModel detailedLoc) {
    if (provinces.isEmpty) return;

    // Find and select province
    final province = provinces.firstWhere(
      (p) => p.provinceId == detailedLoc.provinceId,
      orElse: () => provinces.first,
    );

    setState(() {
      selectedProvince = province;

      // Find and select governorate
      if (province.governorates.isNotEmpty) {
        final governorate = province.governorates.firstWhere(
          (g) => g.govId == detailedLoc.governorateId,
          orElse: () => province.governorates.first,
        );

        selectedGovernorate = governorate;

        // Find and select neighborhood
        if (governorate.neighborhoods.isNotEmpty) {
          final neighborhood = governorate.neighborhoods.firstWhere(
            (n) => n.neighId == detailedLoc.neighborhoodId,
            orElse: () => governorate.neighborhoods.first,
          );

          selectedNeighborhood = neighborhood;
        }
      }
    });
  }

  void _fillOut() {
    try {
      nameController.text = widget.customer.name ?? '';
      emailController.text = widget.customer.email ?? '';
      phoneController.text = widget.customer.phone ?? '';
    } catch (e) {
      _showSnackBar(
        AppLocalizations.of(context)?.errorFillingProfile ??
            'Error filling out profile',
        backgroundColor: AppColors.red,
      );
    }
  }

  void _updateProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      // ✅ Validate location selection
      if (selectedProvince == null ||
          selectedGovernorate == null ||
          selectedNeighborhood == null) {
        _showSnackBar(
          AppLocalizations.of(context)!.pleaseSelectAllLocationFields,
          backgroundColor: AppColors.yellow,
        );
        return;
      }

      // ✅ Create DetailedLocationModel
      final detailedLocation = DetailedLocationModel(
        provinceId: selectedProvince!.provinceId,
        provinceEn: selectedProvince!.provinceEn,
        provinceAr: selectedProvince!.provinceAr,
        governorateId: selectedGovernorate!.govId,
        governorateEn: selectedGovernorate!.govEn,
        governorateAr: selectedGovernorate!.govAr,
        neighborhoodId: selectedNeighborhood!.neighId,
        neighborhoodEn: selectedNeighborhood!.neighEn,
        neighborhoodAr: selectedNeighborhood!.neighAr,
      );

      final updatedCustomer = widget.customer.copyWith(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        detailedLocation: detailedLocation, // ✅ Use DetailedLocationModel
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
    if (phoneNumber.length != 10) return false;
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
      if (mounted) setState(() => isLoading = false);
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
    final isArabic = locale?.localeName == 'ar';

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
          title: Text(locale?.profileManagement ?? 'Profile Management'),
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
              if (isLoadingLocations) const LinearProgressIndicator(),
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
                    return locale?.enterAValidName ?? 'Enter a valid name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

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
                      return locale?.enterAValidEmail ?? 'Enter a valid email';
                    }
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
                suffixIcon: TextButton(
                  onPressed: _updatePhoneNumber,
                  child: Text(locale?.update ?? 'Update'),
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

              // ✅ Location Section Header
              Text(
                locale?.location ?? 'Location',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),

              // ✅ Province Dropdown
              _buildDropdownField<Province>(
                label: '${locale?.province ?? 'Province'} *',
                value: selectedProvince,
                items: provinces,
                itemLabel: (province) => province.getName(isArabic),
                onChanged: (province) {
                  setState(() {
                    selectedProvince = province;
                    selectedGovernorate = null;
                    selectedNeighborhood = null;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return locale?.pleaseSelectProvince ??
                        'Please select a province';
                  }
                  return null;
                },
              ),

              if (selectedProvince != null) ...[
                const SizedBox(height: 16),

                // ✅ Governorate Dropdown
                _buildDropdownField<Governorate>(
                  label: '${locale?.city ?? 'City'} *',
                  value: selectedGovernorate,
                  items: selectedProvince!.governorates,
                  itemLabel: (gov) => gov.getName(isArabic),
                  onChanged: (gov) {
                    setState(() {
                      selectedGovernorate = gov;
                      selectedNeighborhood = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return locale?.pleaseSelectCity ?? 'Please select a city';
                    }
                    return null;
                  },
                ),
              ],

              if (selectedGovernorate != null) ...[
                const SizedBox(height: 16),

                // ✅ Neighborhood Dropdown
                _buildDropdownField<Neighborhood>(
                  label: '${locale?.neighbourhood ?? 'Neighborhood'} *',
                  value: selectedNeighborhood,
                  items: selectedGovernorate!.neighborhoods,
                  itemLabel: (neigh) => neigh.getName(isArabic),
                  onChanged: (neigh) {
                    setState(() {
                      selectedNeighborhood = neigh;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return locale?.pleaseSelectNeighborhood ??
                          'Please select a neighborhood';
                    }
                    return null;
                  },
                ),
              ],

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
                        backgroundColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: state is UpdateCustomerProfileLoading
                          ? Loader(size: 20, color: Colors.white)
                          : Text(
                              locale?.update ?? 'Update',
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

  // ✅ Dropdown builder
  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: GoogleFonts.dmSans(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
        ),
      ],
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
