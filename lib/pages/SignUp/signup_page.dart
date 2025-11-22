import 'dart:convert';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location_selection.dart'; // ✅ Add this
import 'package:abo_glumbo_bbk/models/searchable_dropdown.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SignupPage extends StatefulWidget {
  final String uid;
  const SignupPage({super.key, required this.uid});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isLoading = false;
  bool isCreatingAccount = false;
  bool isLoadingLocations = true;

  final _formkey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // ✅ Location dropdowns (same as technician app)
  List<Region> regions = [];
  Region? selectedRegion;
  City? selectedCity;
  District? selectedDistrict;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  // ✅ Load locations from JSON
  Future<void> _loadLocations() async {
    setState(() => isLoadingLocations = true);
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_hierarchical.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);

      setState(() {
        regions = jsonData.map((r) => Region.fromJson(r)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToLoadLocations ??
                  'Failed to load locations',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: AppLocalizations.of(context)?.retry ?? 'Retry',
              onPressed: _loadLocations,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingLocations = false);
      }
    }
  }

  Future<void> signup() async {
    if (!_formkey.currentState!.validate()) return;

    // ✅ Validate location selection
    if (selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.pleaseSelectProvince ??
                'Please select a province',
          ),
        ),
      );
      return;
    }

    if (selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.pleaseSelectCity ??
                'Please select a city',
          ),
        ),
      );
      return;
    }

    if (selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.pleaseSelectNeighborhood ??
                'Please select a neighborhood',
          ),
        ),
      );
      return;
    }

    // ✅ Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 24, child: Loader(color: AppColors.secondary)),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(dialogContext)?.creatingAccount ??
                      'Creating your account...',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      String phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

      // ✅ Create DetailedLocationModel
      final detailedLocation = DetailedLocationModel(
        regionId: selectedRegion!.regionId,
        regionEn: selectedRegion!.regionEn,
        regionAr: selectedRegion!.regionAr,
        cityId: selectedCity!.cityId,
        cityEn: selectedCity!.cityEn,
        cityAr: selectedCity!.cityAr,
        neighborhoodId: selectedDistrict!.districtId,
        neighborhoodEn: selectedDistrict!.districtEn,
        neighborhoodAr: selectedDistrict!.districtAr,
      );

      CustomerModel customer = CustomerModel(
        role: "customer",
        uid: widget.uid,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneNumber,
        country: "SA",
        detailedLocation: detailedLocation, // ✅ Use DetailedLocationModel
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await AppFirestore.customersCollectionRef
          .doc(widget.uid)
          .set(customer.toJson());

      // ✅ Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        LocalStoreHelper.putUID(widget.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.green,
            content: Text(
              AppLocalizations.of(context)?.accountCreatedSuccessfully ??
                  'Account created successfully!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      // ✅ Close loading dialog on error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToCreateAccount ??
                  'Failed to create account',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool?> showTermsAndConditionsDialog() async {
    final locale = AppLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            locale!.termsAndConditions,
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.byCreatingAnAccountYouAgreeToOur,
                  style: GoogleFonts.dmSans(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final url = 'https://example.com/terms';
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(
                    'https://example.com/terms',
                    style: GoogleFonts.dmSans(
                      color: AppColors.secondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  locale.doYouAccept,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                locale.cancel,
                style: GoogleFonts.dmSans(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                locale.accept,
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final locale = AppLocalizations.of(context);
    final isArabic = locale?.localeName == 'ar';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          },
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Form(
        key: _formkey,
        child: ListView(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: safePadding.bottom + 16,
          ),
          children: [
            if (isLoadingLocations) const LinearProgressIndicator(),
            const SizedBox(height: 25),
            Text(
              locale?.createAccount ?? 'Create Account',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              locale?.pleaseFillTheInputBelowHereToContinue ??
                  'Please fill the input below here to continue',
              style: GoogleFonts.dmSans(color: Colors.black45, fontSize: 14),
            ),
            const SizedBox(height: 34),

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

            // Create Account Button
            SizedBox(
              width: double.maxFinite,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final accepted = await showTermsAndConditionsDialog();
                  if (accepted == true) {
                    await signup();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  locale?.createAccount ?? 'Create Account',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
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
    super.dispose();
  }
}
