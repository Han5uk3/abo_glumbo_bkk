import 'dart:async';

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
import 'package:abo_glumbo_bbk/pages/bookings/searching_technicians_screen.dart';
import 'package:abo_glumbo_bbk/pages/home/bloc/home_bloc.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:abo_glumbo_bbk/models/address.dart';
// import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
// import 'package:abo_glumbo_bbk/sheets/save_address_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/common_widgets/shimmer_loader.dart';

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
  List<ServiceModel> _allServices = [];
  List<CategoryModel> _allCategories = [];
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

    _categoriesSubscription = AppServices.listenToCategories().listen((
      categories,
    ) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _allCategories = categories;
        _categoriesLoaded = true;
        _checkDataStates();
      });
    });
  }

  void _checkDataStates() {
    if (!_isDataLoaded &&
        _bannersLoaded &&
        _servicesLoaded &&
        _categoriesLoaded) {
      setState(() {
        _isDataLoaded = true;
      });
    }
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

  // void _openAddressSheet() {
  //   if (_isGuest) {
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(builder: (context) => const LoginPage()),
  //     );
  //     return;
  //   }

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => AddressSaveSheet(
  //       initialPosition: const {'latitude': 25.276987, 'longitude': 51.520008},
  //     ),
  //   );
  // }

  Widget _buildHeader(EdgeInsets safePadding) {
    return Container(
      color: AppColors.bgWhite,
      child: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 140,
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
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6),
                    height: 50,
                    width: 50,
                    child: Image(
                      fit: BoxFit.cover,
                      image: AssetImage("assets/icons/app_icon.png"),
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${AppLocalizations.of(context)!.welcome}, ${LocalStoreHelper.getUserName()}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),

                  // const SizedBox(width: 8),
                  // Expanded(
                  //   child: _isGuest
                  //       ? InkWell(
                  //           onTap: _openAddressSheet,
                  //           child: _buildAddressText(null),
                  //         )
                  //       : StreamBuilder<CustomerModel>(
                  //           stream: AppServices.listenToCustomerData(
                  //             LocalStoreHelper.getUID() ?? '',
                  //           ),
                  //           builder: (context, snapshot) {
                  //             if (snapshot.hasError || !snapshot.hasData) {
                  //               return InkWell(
                  //                 onTap: _openAddressSheet,
                  //                 child: _buildAddressText(null),
                  //               );
                  //             }
                  //             final addresses = snapshot.data!.addresses;
                  //             final selectedAddress = addresses.isEmpty
                  //                 ? null
                  //                 : addresses.firstWhere(
                  //                     (a) => a.isSelected == true,
                  //                     orElse: () => addresses.first,
                  //                   );
                  //             return InkWell(
                  //               onTap: _openAddressSheet,
                  //               child: _buildAddressText(selectedAddress),
                  //             );
                  //           },
                  //         ),
                  // ),
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
        ],
      ),
    );
  }

  // Widget _buildAddressText(AddressModel? address) {
  //   if (address == null) {
  //     return Column(
  //       mainAxisAlignment: MainAxisAlignment.start,
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Text(
  //           AppLocalizations.of(context)?.addNew ?? "Add address",
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontSize: 10,
  //             fontWeight: FontWeight.w700,
  //           ),
  //         ),
  //         Text(
  //           AppLocalizations.of(context)?.noAddress ?? "No address saved",
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontSize: 8,
  //             fontWeight: FontWeight.w400,
  //           ),
  //         ),
  //       ],
  //     );
  //   }

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     mainAxisAlignment: MainAxisAlignment.start,
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Text(
  //         address.fullName,
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontSize: 12,
  //           fontWeight: FontWeight.w700,
  //         ),
  //         maxLines: 3,
  //         overflow: TextOverflow.ellipsis,
  //       ),
  //       Text(
  //         address.streetName ?? "",
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontSize: 10,
  //           fontWeight: FontWeight.w500,
  //         ),
  //         maxLines: 3,
  //         overflow: TextOverflow.ellipsis,
  //       ),
  //     ],
  //   );
  // }

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
              orElse: () =>
                  _allServices.first, // Should not happen due to filter
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
          style: TextStyle(color: Colors.red),
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

  Widget _buildTrustBar() {
    final locale = AppLocalizations.of(context);
    final items = [
      _TrustItem(
        icon: Icons.verified_user_outlined,
        title: locale?.trustBarWarranty ?? 'Warranty',
        subtitle: locale?.trustBarWarrantyDesc ?? '7-day service guarantee',
      ),
      _TrustItem(
        icon: Icons.bolt_outlined,
        title: locale?.trustBarSpeed ?? 'Speed',
        subtitle: locale?.trustBarSpeedDesc ?? 'Fast & reliable service',
      ),
      _TrustItem(
        icon: Icons.workspace_premium_outlined,
        title: locale?.trustBarQuality ?? 'Quality',
        subtitle: locale?.trustBarQualityDesc ?? 'Certified professionals',
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.06),
            AppColors.secondary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Container(
              width: 1,
              height: 32,
              color: AppColors.grey.withOpacity(0.2),
            );
          }
          final item = items[index ~/ 2];
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 22, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.grey2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHowCanWeHelp() {
    final locale = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 4),
      child: Text(
        locale?.howCanWeHelp ?? 'How can we help you today?',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.black1,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildContinueBookingCard() {
    if (_isGuest) return const SizedBox.shrink();
    final cachedId = LocalStoreHelper.getBookingRequestId();
    if (cachedId == null || cachedId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: AppFirestore.bookingRequestsCollectionRef
          .doc(cachedId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        final status = data['status'] as String?;
        if (createdAt == null) return const SizedBox.shrink();

        if (status == 'closed' || status == 'completed' || status == 'cancelled') {
          LocalStoreHelper.clearBookingRequestId();
          return const SizedBox.shrink();
        }

        final elapsedSeconds = DateTime.now()
            .difference(createdAt.toDate())
            .inSeconds;
        // If more than 5 minutes (300 seconds) have passed, we don't show the card
        if (elapsedSeconds >= 300) {
          // Clear cached request ID
          LocalStoreHelper.clearBookingRequestId();
          return const SizedBox.shrink();
        }

        final isArabic = AppLocalizations.of(context)?.localeName == 'ar';
        final isUrdu = AppLocalizations.of(context)?.localeName == 'ur';

        return Container(
          margin: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SearchingTechniciansScreen(bookingRequestId: cachedId),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic
                                ? 'متابعة حجزك قيد البحث'
                                : isUrdu
                                ? 'اپنی بکنگ جاری رکھیں'
                                : 'Continue your booking search',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isArabic
                                ? 'لديك طلب حجز فني نشط. انقر للمتابعة.'
                                : isUrdu
                                ? 'آپ کے پاس ایک فعال بکنگ تلاش کی جا رہی ہے۔ جاری رکھنے کے لیے کلک کریں۔'
                                : 'You have an active technician search request. Tap to continue.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: HomeCarouselWidget(banners: primaryBanners),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildTrustBar()),
          SliverToBoxAdapter(child: _buildContinueBookingCard()),

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
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),
          SliverToBoxAdapter(child: _buildHowCanWeHelp()),

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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _TrustItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
