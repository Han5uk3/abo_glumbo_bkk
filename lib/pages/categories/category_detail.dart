import 'dart:ui';

import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/shimmer_loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/bookings/book_service_page.dart';
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
  ServiceModel? service;
  bool isLoading = true;

  @override
  void initState() {
    _fetchService();
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

  Future<void> _fetchService() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await AppFirestore.servicesCollectionRef
          .where('category', isEqualTo: widget.category?.id)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          service = ServiceModel.fromQueryDocumentSnapshot(snapshot.docs.first);
          isLoading = false;
        });
      } else {
        setState(() {
          service = null;
          isLoading = false;
        });
      }
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
        body: const Center(
          child: ShimmerLoader(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
        ),
      );
    }

    final service = this.service;
    final imageUrl = service?.image ?? widget.category?.icon ?? '';
    final headerHeight = (MediaQuery.of(context).size.height * 0.35) + 80;

    return Scaffold(
      backgroundColor: AppColors.bgBlueTint,
      body: Stack(
        children: [
          // Main content area
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight),
                  // Custom Header with image and back button
                  SizedBox(
                    height: headerHeight,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            height: headerHeight,
                            width: double.infinity,
                            child:
                                (imageUrl.isNotEmpty &&
                                    Uri.tryParse(imageUrl) != null &&
                                    Uri.tryParse(imageUrl)!.hasAbsolutePath)
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: ShimmerLoader(
                                        width: double.infinity,
                                        height: double.infinity,
                                        borderRadius: 12,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                          ),
                        ),
                        // Frosted back button
                        Positioned.directional(
                          top: 16,
                          start: 16,
                          textDirection: TextDirection.ltr,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                height: 42,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.pop(context),
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Icon(
                                      Icons.arrow_back_ios_new,

                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Discount Badge
                        if (service != null &&
                            (service.discountPercentage ?? 0) > 0)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                "${service.discountPercentage!.toInt()}% ${AppLocalizations.of(context)?.off ?? "OFF"}",
                                style: DMSansFont.textStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Service Details content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 10),
                        Text(
                          service?.nameLocalized(
                                languageCode:
                                    AppLocalizations.of(context)?.localeName ??
                                    '',
                              ) ??
                              widget.category?.nameLocalized(
                                languageCode:
                                    AppLocalizations.of(context)?.localeName ??
                                    '',
                              ) ??
                              '',
                          textAlign: TextAlign.start,
                          style: DMSansFont.textStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 20,
                            height: 1.5,
                          ),
                        ),
                        Divider(color: AppColors.black3.withOpacity(.3)),
                        const SizedBox(height: 12),
                        if (service != null) ...[
                          Card(
                            color: AppColors.bgWhite,
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.aboutThisService,
                                    textAlign: TextAlign.start,
                                    style: DMSansFont.textStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 18,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    service.descriptionLocalized(
                                          languageCode:
                                              AppLocalizations.of(
                                                context,
                                              )?.localeName ??
                                              '',
                                        ) ??
                                        '',
                                    textAlign: TextAlign.start,
                                    style: DMSansFont.textStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            AppLocalizations.of(context)?.noServicesFound ??
                                'No Service Available',
                            style: DMSansFont.textStyle(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Frosted Glass Bottom Bar (Pinned to screen bottom) ---
          if (service != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      border: Border(
                        top: BorderSide(
                          color: Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: eButton(
                              context: context,
                              onPressed: () {
                                if (LocalStoreHelper.getGuestUser()) {
                                  SignUpAlertForGuestUsers().showSignUpAlert(
                                    context,
                                  );
                                } else {
                                  /*
                                  if (!_isServiceAvailableInCustomerRegion(
                                    service,
                                  )) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.serviceNotAvailableInRegion ??
                                              'This service is not available in your region now. It will be added later.',
                                        ),
                                        backgroundColor: Colors.orange,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }
                                  */
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookServicePage(service: service),
                                    ),
                                  );
                                }
                              },
                              backgroundColor: AppColors.primary,
                              textColor: Colors.white,
                              widget: Text(
                                AppLocalizations.of(context)?.requestService ??
                                    'Request Service',
                                style: DMSansFont.textStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
