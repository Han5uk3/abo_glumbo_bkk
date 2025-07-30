import 'package:abo_glumbo_bbk/common_widgets/category_card.dart';
import 'package:abo_glumbo_bbk/common_widgets/highlighted_service.dart';
import 'package:abo_glumbo_bbk/common_widgets/home_carousel.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/banner.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/highlighted_services.dart';
import 'package:abo_glumbo_bbk/pages/home/widgets/location_showing_widget.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notifications.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<BannerModel> banners = [];
  bool _isGuest = false;
  @override
  void initState() {
    try {
      _isGuest = LocalStoreHelper.getGuestUser();
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
    }
    _initialize();
    super.initState();
  }

  // Initialize the state
  void _initialize() {
    try {
      _fetchMainBanners();
      if (_isGuest) {
        _initializeNotifications();
      }
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
    }
  }

  Future<void> _fetchMainBanners() async {
    banners = await AppServices.fetchBanners();
  }

  void _initializeNotifications() async {
    try {
      await NotificationServices.initializeNotifications();
      await NotificationServices.initializeFCM();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing notifications: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final primaryBanners = banners
        .where((element) => element.section == 1)
        .toList();
    final secondaryBanners = banners
        .where((element) => element.section == 2)
        .toList();
    return RefreshIndicator(
      onRefresh: _fetchMainBanners,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300 + safePadding.top,
              child: Stack(
                children: [
                  Container(
                    width: double.maxFinite,
                    height: 250 + safePadding.top,
                    color: AppColors.primary,
                  ),
                  if (!_isGuest)
                    Positioned(
                      top: safePadding.top + 8,
                      right: Directionality.of(context) == TextDirection.rtl
                          ? 16
                          : null,
                      left: Directionality.of(context) == TextDirection.rtl
                          ? null
                          : 16,
                      child: LocationShowingWidget(),
                    ),
                  if (primaryBanners.isNotEmpty)
                    Positioned(
                      top: safePadding.top + 50,
                      right: 0,
                      left: 0,
                      child: HomeCarouselWidget(banners: primaryBanners),
                    ),
                  Positioned(
                    bottom: 15,
                    right: 16,
                    left: 16,
                    child: SearchBar(
                      hintText:
                          AppLocalizations.of(context)?.searchForAService ?? '',
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        // AppNavigation.pushSearch(context);
                      },
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                        // AppNavigation.pushSearch(context, query: value);
                      },
                      leading: const Icon(Icons.search, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ).copyWith(bottom: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.jobCategories ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder(
            stream: AppFirestore.categoriesCollectionRef
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final categories = snapshot.data?.docs ?? [];
              return SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 105,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final category = CategoryModel.fromQuerySnapshot(
                    categories[index],
                  );
                  return Center(child: CategoryCard(category: category));
                }, childCount: categories.length),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: secondaryBanners.isNotEmpty
                  ? HomeCarouselWidget(banners: secondaryBanners)
                  : const SizedBox.shrink(),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: AppFirestore.highlightedServicesCollectionRef
                .where('active', isEqualTo: true)
                .orderBy('sortOrder', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)?.failedToLoadContent ??
                          'Error loading content',
                      style: GoogleFonts.dmSans(color: Colors.red),
                    ),
                  ),
                );
              }
              final highlightedServicesStream =
                  snapshot.data?.docs
                      .map(
                        (e) =>
                            HighlightedServicesModel.fromQueryDocumentSnapshot(
                              e,
                            ),
                      )
                      .toList() ??
                  [];

              if (highlightedServicesStream.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final data = highlightedServicesStream[index];
                  return HighlightedServiceWidget(
                    data: data,
                    isGuestUser: _isGuest,
                  );
                }, childCount: highlightedServicesStream.length),
              );
            },
          ),
        ],
      ),
    );
  }
}
