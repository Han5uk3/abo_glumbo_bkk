import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
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
  bool isLoading = true;
  bool isCreatingAccount = false;
  final _formkey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController districtNameController = TextEditingController();
  final TextEditingController neighbourhoodController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  List<LocationModel> locations = [];

  Future signup() async {
    if (!_formkey.currentState!.validate()) return;

    setState(() => isCreatingAccount = true);

    try {
      String phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

      CustomerModel customer = CustomerModel(
        uid: widget.uid,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneNumber,
        country: "SA",
        cityName: cityController.text.trim(),
        neighbourhood: neighbourhoodController.text.trim(),
        districtName: districtNameController.text.trim(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await AppFirestore.customersCollectionRef
          .doc(widget.uid)
          .set(customer.toJson());

      if (mounted) {
        // Save user UID to local storage after successful signup completion
        LocalStoreHelper.putUID(widget.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.green,
            content: Text(
              AppLocalizations.of(context)?.accountCreatedSuccessfully ?? '',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to home page after successful account creation
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Wait a bit for the snackbar to show

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToCreateAccount ?? '',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() => isCreatingAccount = false);
  }

  Future<bool?> showTermsAndConditionsDialog() async {
    final locale = AppLocalizations.of(context);

    // Use available localization keys: `byContinuingYouAgreeToOur` and `termsOfUseAndPrivacyPolicy`.
    // Use `ok`/`cancel` as action labels to avoid missing getters.
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
                    // Fallback URL; replace with real terms URL if available
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
                SizedBox(height: 16),
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
  void initState() {
    loadLocations();
    super.initState();
  }

  Future loadLocations() async {
    setState(() => isLoading = true);

    try {
      var response = await AppFirestore.locationsCollectionRef.get();
      setState(() {
        locations = response.docs
            .map((e) => LocationModel.fromQuerySnapshot(e))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToLoadLocations ?? '',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: AppLocalizations.of(context)?.retry ?? '',
              onPressed: loadLocations,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
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
                    AppLocalizations.of(context)?.selectLocation ?? '',
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
                itemCount: locations.length,
                padding: EdgeInsets.only(bottom: safePaddings.bottom + 16),
                itemBuilder: (context, index) {
                  final location = locations[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.grey2,
                    ),
                    title: Text(
                      AppLocalizations.of(context)?.localeName == 'ar'
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
            if (isLoading) const Center(child: LinearProgressIndicator()),
            const SizedBox(height: 25),
            Text(
              locale?.createAccount ?? '',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              locale?.pleaseFillTheInputBelowHereToContinue ?? '',
              style: GoogleFonts.dmSans(color: Colors.black45, fontSize: 14),
            ),
            const SizedBox(height: 34),
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
                if (value == null || value.isEmpty) {
                  return locale?.emailIsRequired ?? '';
                } else if (!value.contains("@")) {
                  return locale?.enterAValidEmail ?? '';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormWidget(
              controller: neighbourhoodController,
              label: locale?.neighbourhood ?? '',
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return locale?.neighbourhoodIsRequired ?? '';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormWidget(
              controller: cityController,
              label: locale?.city ?? '',
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
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
              onTap: selectLocationBottomSheet,
              validator: (value) {
                if (districtNameController.text.isEmpty) {
                  return locale?.locationIsRequired ?? '';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.maxFinite,
              height: 55,
              child: ElevatedButton(
                onPressed: isCreatingAccount
                    ? () {}
                    : () async {
                        // Show terms dialog and proceed only if accepted
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
                child: isCreatingAccount
                    ? Loader()
                    : Text(
                        locale?.createAccount ?? '',
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
}
