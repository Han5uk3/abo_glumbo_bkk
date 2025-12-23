import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/sheets/book_service.dart';
import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CategoryDetail extends StatefulWidget {
  final CategoryModel? category;
  const CategoryDetail({super.key, this.category});

  @override
  State<CategoryDetail> createState() => _CategoryDetailState();
}

class _CategoryDetailState extends State<CategoryDetail> {
  List<ServiceModel> allServices = [];
  bool isLoading = true;

  @override
  void initState() {
    _fetchAllServices();
    _ensureCustomerDataLoaded();
    super.initState();
  }

  void _ensureCustomerDataLoaded() {
    final uid = LocalStoreHelper.getUID();
    final isGuest = LocalStoreHelper.getGuestUser();

    if (!isGuest && uid != null && uid.isNotEmpty) {
      final currentState = context.read<AccountBloc>().state;

      if (currentState is! CustomerDataLoaded) {
        context.read<AccountBloc>().add(ListenCustomerData(uid: uid));
      }
    }
  }

  Future<void> _fetchAllServices() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await AppFirestore.servicesCollectionRef
          .where('category', isEqualTo: widget.category?.id)
          .where('isActive', isEqualTo: true)
          .get();

      final services = snapshot.docs.map((e) {
        return ServiceModel.fromQueryDocumentSnapshot(e);
      }).toList();

      setState(() {
        allServices = services;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.failedToLoadServices ?? ''}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: Loader(color: Colors.white)),
      );
    }

    final service = allServices.isNotEmpty ? allServices.first : null;
    final imageUrl = service?.image ?? widget.category?.icon ?? '';

    // Header height (70% of screen height)
    final headerHeight = MediaQuery.of(context).size.height * 0.70;

    return Scaffold(
      backgroundColor: AppColors.primary,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // --- HEADER SECTION ---
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                color: Colors.white,
              ),
              height: headerHeight,
              width: double.infinity,
              // The White Frame
              // PADDING: Creates the white border
              padding: const EdgeInsets.all(16),

              child:
                  (imageUrl.isNotEmpty &&
                      Uri.tryParse(imageUrl) != null &&
                      Uri.tryParse(imageUrl)!.hasAbsolutePath)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Center(child: Loader(color: AppColors.primary)),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    ),
            ),

            // --- CONTENT SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 0,
              ),
              child: Column(
                children: [
                  if (service != null) ...[
                    const SizedBox(height: 30),
                    Text(
                      service.nameLocalized(
                            languageCode:
                                AppLocalizations.of(context)?.localeName ?? '',
                          ) ??
                          '',
                      textAlign: TextAlign.center,
                      style: DMSansFont.textStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      service.descriptionLocalized(
                            languageCode:
                                AppLocalizations.of(context)?.localeName ?? '',
                          ) ??
                          '',
                      textAlign: TextAlign.center,
                      style: DMSansFont.textStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 30),

                    Text(
                      "${AppLocalizations.of(context)?.inspectionFee ?? 'Inspection Fee'}: ${service.price} ${AppLocalizations.of(context)?.sar ?? 'SAR'}",
                      style: DMSansFont.textStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (LocalStoreHelper.getGuestUser()) {
                            SignUpAlertForGuestUsers().showSignUpAlert(context);
                          } else {
                            showBookServiceBottomSheet(
                              context,
                              service: service,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.requestService ??
                              'Request Service',
                          style: DMSansFont.textStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ] else ...[
                    Text(
                      AppLocalizations.of(context)?.noServicesFound ??
                          'No Service Available',
                      style: DMSansFont.textStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
