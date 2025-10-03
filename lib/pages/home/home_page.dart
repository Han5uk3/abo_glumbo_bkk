import 'package:abo_glumbo_bbk/common_widgets/category_card.dart';
import 'package:abo_glumbo_bbk/common_widgets/highlighted_service.dart';
import 'package:abo_glumbo_bbk/common_widgets/home_carousel.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/banner.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/highlighted_services.dart';
import 'package:abo_glumbo_bbk/pages/home/active_bookings/active_bookings.dart';
import 'package:abo_glumbo_bbk/pages/home/bloc/home_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/search/search_page.dart';
import 'package:abo_glumbo_bbk/pages/home/widgets/location_showing_widget.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notifications.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<BannerModel> _banners = [];
  bool _isGuest = false;
  bool _isInitialized = false;
  DateTime? _lastRefresh;
  bool _isDisposed = false;

  static const Duration _refreshThreshold = Duration(minutes: 5);
  static const Duration _sessionTimeout = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _initializeSync();
    _initializeAsync();
  }

  void _initializeSync() {
    try {
      _isGuest = LocalStoreHelper.getGuestUser();
    } catch (e) {
      debugPrint('❌ Error getting guest user: $e');
      _isGuest = false;
    }
  }

  Future<void> _initializeAsync() async {
    if (_isInitialized || _isDisposed) return;
    try {
      await Future.wait([
        _fetchMainBanners(),
        if (!_isGuest) _fetchActiveBookings(),
        if (!_isGuest) _initializeAuthenticatedUser(),
      ]);
      await NotificationServices.initializeFCM();
      if (!_isDisposed) {
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('❌ Error during async initialization: $e');
    }
  }

  Future<void> _fetchActiveBookings() async {
    context.read<HomeBloc>().add(FetchActiveBookings());
  }

  Future<void> _initializeAuthenticatedUser() async {
    if (_isDisposed) return;
    try {
      // FCM is already initialized in main.dart, just refresh the token
      await NotificationServices.refreshFCMToken();
      if (!_isDisposed) {
        WidgetsBinding.instance.addObserver(this);
      }
    } catch (e) {
      debugPrint('❌ Error initializing authenticated user: $e');
    }
  }

  Future<void> _fetchMainBanners({bool forceRefresh = false}) async {
    if (_isDisposed) return;
    try {
      if (!forceRefresh &&
          _banners.isNotEmpty &&
          _lastRefresh != null &&
          DateTime.now().difference(_lastRefresh!) < _refreshThreshold) {
        return;
      }

      final newBanners = await AppServices.fetchBanners();
      if (mounted && !_isDisposed) {
        setState(() {
          _banners = newBanners;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching banners: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!mounted || _isDisposed) return;

    switch (state) {
      case AppLifecycleState.paused:
        await LocalStoreHelper.saveBackgroundTime();
        break;
      case AppLifecycleState.resumed:
        // Temporarily disable session checking to prevent navigation issues
        // await _checkSession();
        break;
      default:
        break;
    }
  }

  List<BannerModel> _getPrimaryBanners() {
    return _banners.where((banner) => banner.section == 1).toList();
  }

  List<BannerModel> _getSecondaryBanners() {
    return _banners.where((banner) => banner.section == 2).toList();
  }

  Widget _buildHeader(EdgeInsets safePadding) {
    final primaryBanners = _getPrimaryBanners();

    return SizedBox(
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
              left: Directionality.of(context) == TextDirection.rtl ? null : 16,
              child: const LocationShowingWidget(),
            ),
          if (primaryBanners.isNotEmpty)
            Positioned(
              top: safePadding.top + 50,
              right: 0,
              left: 0,
              child: HomeCarouselWidget(banners: primaryBanners),
            ),

          Positioned(bottom: 15, right: 16, left: 16, child: _buildSearchBar()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SearchBar(
      hintText: AppLocalizations.of(context)?.searchForAService ?? '',
      onTap: () {
        FocusScope.of(context).unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SearchPage()),
        );
      },
      onSubmitted: (value) {
        FocusScope.of(context).unfocus();
      },
      leading: const Icon(Icons.search, color: Colors.black45),
    );
  }

  Widget _buildCategoriesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 9),
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
    );
  }

  Widget _buildCategoriesGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: AppFirestore.categoriesCollectionRef
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (_isDisposed) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _buildErrorWidget('Error loading categories'),
          );
        }
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final categories = snapshot.data!.docs;
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            mainAxisSpacing: 8,
            mainAxisExtent: 105,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final category = CategoryModel.fromQuerySnapshot(categories[index]);
            return Center(child: CategoryCard(category: category));
          }, childCount: categories.length),
        );
      },
    );
  }

  Widget _buildHighlightedServices() {
    return StreamBuilder<QuerySnapshot>(
      stream: AppFirestore.highlightedServicesCollectionRef
          .where('active', isEqualTo: true)
          .orderBy('sortOrder', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (_isDisposed) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _buildErrorWidget('Error loading highlighted services'),
          );
        }
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final services = snapshot.data!.docs
            .map(
              (doc) => HighlightedServicesModel.fromQueryDocumentSnapshot(doc),
            )
            .toList();
        if (services.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return HighlightedServiceWidget(
              data: services[index],
              isGuestUser: _isGuest,
            );
          }, childCount: services.length),
        );
      },
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          style: GoogleFonts.dmSans(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_isDisposed) return;
    await _fetchMainBanners(forceRefresh: true);
    if (!_isGuest) _fetchActiveBookings();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final secondaryBanners = _getSecondaryBanners();
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(safePadding)),
          if (!_isGuest)
            BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                if (state is FetchActiveBookingLoading) {
                  return const SliverToBoxAdapter(
                    child: Center(child: Loader()),
                  );
                }
                if (state is FetchActiveBookingSuccess &&
                    state.activeBookings.isNotEmpty) {
                  return SliverToBoxAdapter(
                    child: ActiveBookingsSection(
                      activeBookings: state.activeBookings,
                    ),
                  );
                }
                if (state is FetchActiveBookingError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading active bookings: ${state.error}',
                        style: GoogleFonts.dmSans(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),
          SliverToBoxAdapter(child: _buildCategoriesHeader()),
          _buildCategoriesGrid(),

          if (secondaryBanners.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: HomeCarouselWidget(banners: secondaryBanners),
              ),
            ),
          _buildHighlightedServices(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
