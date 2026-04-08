import 'dart:async';
import 'dart:ui';

import 'package:abo_glumbo_bbk/common_widgets/category_card.dart';
import 'package:abo_glumbo_bbk/common_widgets/highlighted_service.dart';
import 'package:abo_glumbo_bbk/common_widgets/home_carousel.dart';
import 'package:abo_glumbo_bbk/common_widgets/unread_notifications_badge.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/banner.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/highlighted_services.dart';
import 'package:abo_glumbo_bbk/pages/accounts/notification.dart';
import 'package:abo_glumbo_bbk/pages/home/active_bookings/active_bookings.dart';
import 'package:abo_glumbo_bbk/pages/home/bloc/home_bloc.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/sheets/save_address_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:abo_glumbo_bbk/common_widgets/shimmer_loader.dart';
import 'package:abo_glumbo_bbk/pages/bookings/book_service_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  List<BannerModel> _banners = [];
  bool _isGuest = false;
  bool _isInitialized = false;
  DateTime? _lastRefresh;
  bool _isDisposed = false;
  final TextEditingController _searchController = TextEditingController();
  List<ServiceModel> _allServices = [];
  List<CategoryModel> _allCategories = [];
  List<ServiceModel> _filteredServices = [];
  List<CategoryModel> _filteredCategories = [];
  bool _isSearching = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _searchLayerLink = LayerLink();

  bool _isDataLoaded = false;
  bool _bannersLoaded = false;
  bool _servicesLoaded = false;
  bool _categoriesLoaded = false;
  
  static const Duration _refreshThreshold = Duration(minutes: 5);
  static const Duration _sessionTimeout = Duration(minutes: 30);
  
  StreamSubscription? _bannersSubscription;
  StreamSubscription? _servicesSubscription;
  StreamSubscription? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _isGuest = LocalStoreHelper.getGuestUser();
    _initializeSync();
    _initializeAsync();
    _startListeners();
  }

  void _startListeners() {
    _bannersSubscription = AppServices.listenToBanners().listen((banners) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _banners = banners;
        _bannersLoaded = true;
        _checkDataStates();
      });
    });

    _servicesSubscription = AppServices.listenToServices().listen((services) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _allServices = services;
        _servicesLoaded = true;
        _checkDataStates();
      });
    });

    _categoriesSubscription = AppServices.listenToCategories().listen((categories) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _allCategories = categories;
        _categoriesLoaded = true;
        _checkDataStates();
      });
    });
  }

  void _checkDataStates() {
    if (!_isDataLoaded && _bannersLoaded && _servicesLoaded && _categoriesLoaded) {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }


  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredServices = [];
        _filteredCategories = [];
        _isSearching = false;
      });
      _hideSearchDropdown();
      return;
    }

    final queryLower = query.toLowerCase().trim();

    final filteredServices = _allServices.where((service) {
      final nameEn = (service.name ?? '').toLowerCase();
      final nameAr = (service.name_ar ?? '').toLowerCase();
      final descEn = (service.description ?? '').toLowerCase();
      final descAr = (service.description_ar ?? '').toLowerCase();

      return nameEn.contains(queryLower) ||
          nameAr.contains(queryLower) ||
          descEn.contains(queryLower) ||
          descAr.contains(queryLower);
    }).toList();

    setState(() {
      _filteredServices = filteredServices;
      _filteredCategories = []; // Only showing services as requested
      _isSearching = true;
    });

    if (filteredServices.isNotEmpty) {
      _showSearchDropdown();
    } else {
      _hideSearchDropdown();
    }
  }

  void _showSearchDropdown() {
    _hideSearchDropdown();

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSearchDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
              _hideSearchDropdown();
            },
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.transparent,
            ),
          ),
          Positioned(
            width: size.width - 48,
            child: CompositedTransformFollower(
              link: _searchLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 45),
              child: Material(
                elevation: 12,
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        children: [
                          if (_filteredServices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.noServicesFound ??
                                      'No services found',
                                  style: DMSansFont.textStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ..._filteredServices.map(
                            (service) => Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.grey[100],
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child:
                                        (service.image != null &&
                                            service.image!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: service.image!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child: ShimmerLoader(
                                                    width: 40,
                                                    height: 40,
                                                    borderRadius: 10,
                                                  ),
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => const Icon(
                                                  Icons.miscellaneous_services,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                          )
                                        : const Icon(
                                            Icons.miscellaneous_services,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  service.nameLocalized(
                                        languageCode:
                                            AppLocalizations.of(
                                              context,
                                            )?.localeName ??
                                            '',
                                      ) ??
                                      '',
                                  style: DMSansFont.textStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((service.discountPercentage ?? 0) > 0)
                                      Text(
                                        "${service.price} ${AppLocalizations.of(context)!.sar}",
                                        style: DMSansFont.textStyle(
                                          fontSize: 9,
                                          color: Colors.black26,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    Text(
                                      "${service.getDiscountedPrice(service.price ?? 0)} ${AppLocalizations.of(context)!.sar}",
                                      style: DMSansFont.textStyle(
                                        fontSize: 11,
                                        color: AppColors.green1,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                onTap: () {
                                  _searchController.clear();
                                  _hideSearchDropdown();
                                  FocusScope.of(context).unfocus();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookServicePage(service: service),
                                    ),
                                  );
                                },
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
          ),
        ],
      ),
    );
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
      // FCM is already initialized in main.dart
      // Token refresh is now handled on login (AuthServices.checkUser)
      // await NotificationServices.refreshFCMToken();
      if (!_isDisposed) {
        WidgetsBinding.instance.addObserver(this);
      }
    } catch (e) {
      debugPrint('❌ Error initializing authenticated user: $e');
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

  void _openAddressSheet() {
    if (_isGuest) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressSaveSheet(
        initialPosition: const {'latitude': 25.276987, 'longitude': 51.520008},
      ),
    );
  }

  Widget _buildHeader(EdgeInsets safePadding) {
    return Container(
      color: AppColors.bgWhite,
      child: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 232,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              image: const DecorationImage(
                image: AssetImage("assets/images/appbarbg.png"),
                repeat: ImageRepeat.repeat,
                fit: BoxFit.fitHeight,
                opacity: 0.4,
              ),
            ),
          ),
          Positioned(
            top: safePadding.top + 16,
            left: 20,
            right: 20,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _openAddressSheet,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isGuest
                        ? _buildAddressText(null)
                        : StreamBuilder<CustomerModel>(
                            stream: AppServices.listenToCustomerData(
                              LocalStoreHelper.getUID() ?? '',
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasError || !snapshot.hasData) {
                                return _buildAddressText(null);
                              }
                              final addresses = snapshot.data!.addresses;
                              final selectedAddress = addresses.isEmpty
                                  ? null
                                  : addresses.firstWhere(
                                      (a) => a.isSelected == true,
                                      orElse: () => addresses.first,
                                    );
                              return _buildAddressText(selectedAddress);
                            },
                          ),
                  ),
                  SizedBox(width: 20),
                  if (!_isGuest)
                    UnreadNotificationBadge(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const NewNotificationsPage(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: CompositedTransformTarget(
              link: _searchLayerLink,
              child: _buildSearchBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressText(AddressModel? address) {
    if (address == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)?.addNew ?? "Add address",
            style: DMSansFont.textStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            AppLocalizations.of(context)?.noAddress ?? "No address saved",
            style: DMSansFont.textStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          address.streetName ?? "",
          style: DMSansFont.textStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  cursorColor: Colors.white,
                  style: DMSansFont.textStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context)?.searchForAService ?? '',
                    hintStyle: DMSansFont.textStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _performSearch,
                  onSubmitted: (value) {
                    _performSearch(value);
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.7),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.categories,
                  style: DMSansFont.textStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                // Text(
                //   maxLines: 2,
                //   AppLocalizations.of(context)!.categoriesDescription,
                //   style: DMSansFont.textStyle(
                //     fontSize: 13,
                //     fontWeight: FontWeight.w500,
                //     color: Colors.black54,
                //   ),
                // ),
              ],
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
        if (!snapshot.hasData || !_isDataLoaded) {
          return const CategoryGridShimmer();
        }
        final filteredDocs = snapshot.data!.docs.where((doc) {
          return _allServices.any((service) => service.category == doc.id);
        }).toList();

        if (filteredDocs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            mainAxisExtent: 125,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final categoryDoc = filteredDocs[index];
            final category = CategoryModel.fromQuerySnapshot(categoryDoc);

            // Find the service associated with this category to get its discount
            final associatedService = _allServices.firstWhere(
              (service) => service.category == categoryDoc.id,
              orElse: () => _allServices.first, // Should not happen due to filter
            );

            return Center(
              child: CategoryCard(
                category: category,
                discountPercentage: associatedService.discountPercentage,
              ),
            );
          }, childCount: filteredDocs.length),
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
          style: DMSansFont.textStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_isDisposed) return;
    // Manual refresh is less necessary with streams, but we can re-fetch active bookings
    if (!_isGuest) _fetchActiveBookings();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final safePadding = MediaQuery.of(context).padding;
    final primaryBanners = _getPrimaryBanners();
    final secondaryBanners = _getSecondaryBanners();
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(safePadding)),
          SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: HomeCarouselWidget(banners: primaryBanners),
          ),

          if (!_isGuest)
            BlocConsumer<HomeBloc, HomeState>(
              listener: (context, state) {
                if (state is FetchActiveBookingSuccess &&
                    state.activeBookings.isEmpty) {
                  // Cancel tracking notification when no active bookings
                  NotificationServices.cancelTrackingNotification();
                }
              },
              builder: (context, state) {
                if (state is FetchActiveBookingLoading) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
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
                        style: DMSansFont.textStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),
          if (!_isDataLoaded ||
              (_isDataLoaded &&
                  _allCategories.any((cat) =>
                      _allServices.any((service) => service.category == cat.id))))
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
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _isDisposed = true;
    _bannersSubscription?.cancel();
    _servicesSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _hideSearchDropdown();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
