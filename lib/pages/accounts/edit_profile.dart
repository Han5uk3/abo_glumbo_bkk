import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
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

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
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
      final updatedCustomer = CustomerModel(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        districtName: districtNameController.text.trim(),
      );

      context.read<AccountBloc>().add(
        UpdateCustomerProfile(customerData: updatedCustomer),
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

  void _updatePhoneNumber() {
    setState(() => isLoading = true);

    // Simulate phone number update process
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar(
          AppLocalizations.of(context)?.otpSent ?? 'OTP sent successfully',
          backgroundColor: AppColors.green,
        );
      }
    });
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
                  FilteringTextInputFormatter.allow(RegExp(r'^\+?[0-9]*')),
                  LengthLimitingTextInputFormatter(13),
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
