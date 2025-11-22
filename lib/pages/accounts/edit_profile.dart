import 'dart:convert';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location_selection.dart'; // ✅ Add this
import 'package:abo_glumbo_bbk/models/searchable_dropdown.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
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
  List<Region> regions = [];
  Region? selectedRegion;
  City? selectedCity;
  District? selectedDistrict;

  @override
  void initState() {
    super.initState();

    // Load data first, then fill content after frame is built
    loadLocations();

    // Schedule fillContent after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fillOut();
      }
    });
  }

  // ✅ Load locations from JSON
  Future<void> loadLocations() async {
    setState(() {
      isLoadingLocations = true;
    });

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_hierarchical.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);

      if (mounted) {
        setState(() {
          regions = jsonData.map((r) => Region.fromJson(r)).toList();
          isLoadingLocations = false;
        });

        // Pre-select location AFTER regions are loaded and state is set
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.customer.detailedLocation != null && mounted) {
            preselectLocation(widget.customer.detailedLocation!);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading locations: $e');
      }
      if (mounted) {
        setState(() {
          isLoadingLocations = false;
        });
      }
    }
  }

  // ✅ Pre-select saved location
  void preselectLocation(DetailedLocationModel detailedLoc) {
    if (regions.isEmpty || !mounted) return;

    final region = regions.firstWhere(
      (r) => r.regionId == detailedLoc.regionId,
      orElse: () => regions.first,
    );

    setState(() {
      selectedRegion = region;

      if (region.cities.isNotEmpty) {
        final city = region.cities.firstWhere(
          (c) => c.cityId == detailedLoc.cityId,
          orElse: () => region.cities.first,
        );
        selectedCity = city;

        if (city.districts.isNotEmpty) {
          final district = city.districts.firstWhere(
            (d) => d.districtId == detailedLoc.neighborhoodId,
            orElse: () => city.districts.first,
          );
          selectedDistrict = district;
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
      if (selectedRegion == null ||
          selectedCity == null ||
          selectedDistrict == null) {
        _showSnackBar(
          AppLocalizations.of(context)!.pleaseSelectAllLocationFields,
          backgroundColor: AppColors.yellow,
        );
        return;
      }

      // ✅ Create DetailedLocationModel
      final detailedLocation = DetailedLocationModel(
        regionId: selectedRegion?.regionId,
        regionEn: selectedRegion?.regionEn,
        regionAr: selectedRegion?.regionAr,
        cityId: selectedCity?.cityId,
        cityEn: selectedCity?.cityEn,
        cityAr: selectedCity?.cityAr,
        neighborhoodId: selectedDistrict?.districtId,
        neighborhoodEn: selectedDistrict?.districtEn,
        neighborhoodAr: selectedDistrict?.districtAr,
        lat: selectedDistrict?.latitude,
        lon: selectedDistrict?.longitude,
      );

      final updatedCustomer = widget.customer.copyWith(
        role: "customer",
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
              _buildDropdownField<Region>(
                label: '${locale?.province ?? 'Region'} *',
                value: selectedRegion,
                items: regions,
                itemLabel: (region) => region.getName(isArabic),
                onChanged: (region) {
                  setState(() {
                    selectedRegion = region;
                    selectedCity = null;
                    selectedDistrict = null;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return locale?.pleaseSelectProvince ??
                        'Please select a region';
                  }
                  return null;
                },
              ),

              if (selectedRegion != null) ...[
                const SizedBox(height: 16),

                // ✅ City Dropdown
                _buildDropdownField<City>(
                  label: '${locale?.city ?? 'City'} *',
                  value: selectedCity,
                  items: selectedRegion!.cities,
                  itemLabel: (city) => city.getName(isArabic),
                  onChanged: (city) {
                    setState(() {
                      selectedCity = city;
                      selectedDistrict = null;
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

              if (selectedCity != null) ...[
                const SizedBox(height: 16),

                // ✅ District Dropdown
                _buildDropdownField<District>(
                  label: '${locale?.neighbourhood ?? 'District'} *',
                  value: selectedDistrict,
                  items: selectedCity!.districts,
                  itemLabel: (district) => district.getName(isArabic),
                  onChanged: (district) {
                    setState(() {
                      selectedDistrict = district;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return locale?.pleaseSelectNeighborhood ??
                          'Please select a district';
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
  Widget _buildDropdownField<T extends Object>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return SearchableDropdown<T>(
      label: label,
      value: value,
      items: items,
      itemLabel: itemLabel,
      onChanged: onChanged,
      validator: validator,
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
