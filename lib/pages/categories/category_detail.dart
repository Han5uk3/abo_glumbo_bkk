import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
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

    // Header height (Adjusted to 55% to match the deep curve in screenshot)
    final headerHeight = MediaQuery.of(context).size.height * 0.55;

    return Scaffold(
      backgroundColor: AppColors.primary,
      // 1. Extend body behind AppBar so image goes to top of screen
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.primary, // Transparent AppBar
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.category?.nameLocalized(
                languageCode: AppLocalizations.of(context)?.localeName ?? '',
              ) ??
              '',
          style: const TextStyle(color: Colors.white),
        ),
      ),

      body: SingleChildScrollView(
        // Remove padding here so the image touches edges
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // --- HEADER SECTION WITH CURVE ---
            ClipPath(
              clipper:
                  _HeaderCurveClipper(), // The custom clipper defined below
              child: Container(
                height: headerHeight,
                width: double.infinity,
                color: Colors.grey[200], // Placeholder color
                child:
                    (imageUrl.isNotEmpty &&
                        Uri.tryParse(imageUrl) != null &&
                        Uri.tryParse(imageUrl)!.hasAbsolutePath)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover, // Important: fills the curved area
                        placeholder: (context, url) =>
                            Center(child: Loader(color: AppColors.primary)),
                        errorWidget: (context, url, error) => const Center(
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

            // --- CONTENT SECTION ---
            Padding(
              // Add padding back here for the text content
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  if (service != null) ...[
                    Text(
                      service.descriptionLocalized(
                            languageCode:
                                AppLocalizations.of(context)?.localeName ?? '',
                          ) ??
                          '',
                      textAlign: TextAlign.center,
                      style: DMSansFont.textStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      "${AppLocalizations.of(context)?.inspectionFee ?? 'Inspection Fee'}: ${service.price} ${AppLocalizations.of(context)?.sar ?? 'SAR'}",
                      style: DMSansFont.textStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 50),

                    SizedBox(
                      width: double.infinity,
                      height: 56,

                      child: eButton(
                        context: context,
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
                        backgroundColor: Colors.white,
                        textColor: AppColors.primary,

                        widget: Text(
                          AppLocalizations.of(context)?.requestService ??
                              'Request Service',
                          style: DMSansFont.textStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
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

// --- CUSTOM CLIPPER FOR THE CURVED BOTTOM ---
class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    // Start at top-left
    path.lineTo(0, 0);

    // Go to bottom-left (minus the curve height)
    path.lineTo(0, size.height - 50);

    // Create the convex curve (bulging downwards)
    // Control point is in the middle, pushed down below the height
    var firstControlPoint = Offset(size.width / 2, size.height + 20);
    var firstEndPoint = Offset(size.width, size.height - 50);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Go to top-right
    path.lineTo(size.width, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
