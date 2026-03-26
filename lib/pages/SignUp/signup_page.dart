import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/terms_and_conditions_page.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class SignupPage extends StatefulWidget {
  final String uid;
  const SignupPage({super.key, required this.uid});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isLoading = false;

  final _formkey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('📝 SignupPage initialized for UID: ${widget.uid}');
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
      String phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      debugPrint('📱 Creating customer with phone: $phoneNumber');

      // Create customer model
      CustomerModel customer = CustomerModel(
        role: "customer",
        uid: widget.uid,
        name: nameController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        phone: phoneNumber,
        country: "SA",
        addresses: [], // Empty addresses list initially
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
