import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/terms_and_conditions_page.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

class SignupPage extends StatefulWidget {
  final String uid;
  const SignupPage({super.key, required this.uid});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isLoading = false;
  bool isFetchingLocation = false;

  final _formkey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('📝 SignupPage initialized for UID: ${widget.uid}');
  }

  /// Fetch current GPS location and create a "Current Location" address
  Future<AddressModel?> _createCurrentLocationAddress() async {
    debugPrint('📍 Starting to fetch current location for registration...');

    try {
      setState(() => isFetchingLocation = true);

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied by user');
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        throw Exception('Location permission permanently denied');
      }

      debugPrint('✅ Location permission granted, fetching position...');

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint(
        '📍 Position fetched: ${position.latitude}, ${position.longitude}',
      );

      // Reverse geocode to get address name
      String addressName = 'Current Location';
      try {
        final locationName =
            await LocationMatcherService.getLocationNameFromCoordinates(
              latitude: position.latitude,
              longitude: position.longitude,
            );
        if (locationName != null && locationName.isNotEmpty) {
          addressName = locationName;
          debugPrint('📍 Reverse geocoded address: $addressName');
        } else {
          debugPrint('⚠️ Reverse geocoding returned null, using default name');
        }
      } catch (e) {
        debugPrint('⚠️ Reverse geocoding failed: $e, using default name');
      }

      // Get phone number from Firebase Auth
      final phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      debugPrint('📱 Phone number from auth: $phoneNumber');

      // Create address model
      final address = AddressModel(
        id: const Uuid().v4(),
        fullName: addressName,
        buildingNumber: 'N/A', // Placeholder
        phoneNumber: phoneNumber,
        streetName: null,
        lat: position.latitude,
        lon: position.longitude,
        isSelected: true, // Set as default selected
        isCurrentLocation: true, // Mark as auto-updated location
      );

      debugPrint('✅ Current location address created: ${address.id}');
      return address;
    } catch (e) {
      debugPrint('❌ Error creating current location address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToFetchLocation ??
                  'Failed to fetch location. Please enable location services.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => isFetchingLocation = false);
      }
    }
  }

  Future<void> signup() async {
    debugPrint('🚀 Starting signup process...');

    if (!_formkey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 24, child: Loader(color: AppColors.secondary)),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(dialogContext)?.creatingAccount ??
                      'Creating your account...',
                  style: DMSansFont.textStyle(
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
      debugPrint('📍 Fetching current location...');

      // Fetch current location and create address
      final currentLocationAddress = await _createCurrentLocationAddress();

      if (currentLocationAddress == null) {
        debugPrint('❌ Failed to create current location address');
        if (mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pop(); // Close loading dialog
        }
        return;
      }

      debugPrint('✅ Current location address created successfully');

      String phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      debugPrint('📱 Creating customer with phone: $phoneNumber');

      // Create customer model with current location address
      CustomerModel customer = CustomerModel(
        role: "customer",
        uid: widget.uid,
        name: nameController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        phone: phoneNumber,
        country: "SA",
        addresses: [
          currentLocationAddress,
        ], // Add current location to addresses
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      debugPrint('💾 Saving customer to Firestore...');
      await AppFirestore.customersCollectionRef
          .doc(widget.uid)
          .set(customer.toJson());

      debugPrint('✅ Customer created successfully in Firestore');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        LocalStoreHelper.putUID(widget.uid);
        debugPrint('✅ UID saved to local storage');

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

        // Navigate to home with isNewRegistration flag
        if (mounted) {
          debugPrint('🏠 Navigating to home page...');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const Home(isNewRegistration: true),
            ),
            (route) => false,
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error during signup: $e');
      debugPrint('Stack trace: $stackTrace');

      // Close loading dialog on error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToCreateAccount ??
                  'Failed to create account: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.white,
          actionsAlignment: MainAxisAlignment.start,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            locale!.termsAndConditions,
            style: DMSansFont.textStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.byCreatingAnAccountYouAgreeToOur,
                  style: DMSansFont.textStyle(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const TermsAndConditionsPage(isFromLogin: false),
                      ),
                    );
                  },
                  child: Text(
                    locale.termsAndConditions,
                    style: DMSansFont.textStyle(
                      color: AppColors.secondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  locale.doYouAccept,
                  style: DMSansFont.textStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: [
            eButton(
              onPressed: () => Navigator.of(context).pop(false),
              context: context,
              backgroundColor: AppColors.secondary,
              textColor: Colors.white,
              text: locale.cancel,
            ),
            eButton(
              onPressed: () => Navigator.of(context).pop(true),
              context: context,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              text: locale.accept,
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
            if (isFetchingLocation)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),
            const SizedBox(height: 25),
            Text(
              locale?.createAccount ?? 'Create Account',
              style: DMSansFont.textStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              locale?.pleaseFillTheInputBelowHereToContinue ??
                  'Please fill the input below here to continue',
              style: DMSansFont.textStyle(color: Colors.black45, fontSize: 14),
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

            // Email Field (Optional)
            TextFormWidget(
              controller: emailController,
              label:
                  '${locale?.emailAddress ?? 'Email Address'} (${locale?.optional ?? 'Optional'})',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
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
            const SizedBox(height: 24),

            // Location Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.secondary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      locale?.locationWillBeAutomaticallyDetected ??
                          'Your current location will be automatically detected during registration',
                      style: DMSansFont.textStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Create Account Button
            SizedBox(
              width: double.maxFinite,
              height: 55,
              child: ElevatedButton(
                onPressed: isFetchingLocation
                    ? null
                    : () async {
                        final accepted = await showTermsAndConditionsDialog();
                        if (accepted == true) {
                          await signup();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  locale?.createAccount ?? 'Create Account',
                  style: DMSansFont.textStyle(
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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }
}
