// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/sheets/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryDetail extends StatefulWidget {
  final CategoryModel? category;
  const CategoryDetail({super.key, this.category});

  @override
  State<CategoryDetail> createState() => _CategoryDetailState();
}

class _CategoryDetailState extends State<CategoryDetail> {
  List<ServiceModel> allServices = [];
  List<ServiceModel> filteredServices = [];
  Set<String>? selectedDistricts;
  Set<int>? selectedRatings;
  Set<int>? selectedPriceRanges;
  String? updatingServiceId;
  String searchQuery = '';
  bool? isGuestUser;
  bool isLoading = true;
  int selectedFilter = 0;
  double? minPrice;
  double? maxPrice;
  bool hasActiveFilter = false;
  @override
  void initState() {
    _fetchAllServices();
    super.initState();
  }

  Future<void> _fetchAllServices() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await AppFirestore.servicesCollectionRef
          .where('category', isEqualTo: widget.category?.id)
          .where('isActive', isEqualTo: true)
          .get();

      print(snapshot.docs.length);

      final services = snapshot.docs.map((e) {
        return ServiceModel.fromQueryDocumentSnapshot(e);
      }).toList();

      setState(() {
        allServices = services;
        filteredServices = services;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
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
    final safePadding = MediaQuery.of(context).padding;
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  widget.category?.nameLocalized(
                        languageCode:
                            AppLocalizations.of(context)?.localeName ?? '',
                      ) ??
                      '',
                ),
                pinned: true,
                primary: true,
                centerTitle: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(55),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0).copyWith(top: 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SearchBar(
                            hintText:
                                AppLocalizations.of(context)?.searchHere ?? '',
                            onChanged: _filterServices,
                            leading: const Icon(
                              Icons.search,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _openFilter,
                          icon: Stack(
                            children: [
                              const Icon(Icons.tune, color: Colors.white),
                              if (hasActiveFilter)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isLoading)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 11,
                    top: 31,
                    left: 16,
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${AppLocalizations.of(context)?.availableServices ?? ''} (${filteredServices.length})',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_alt,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)?.filtered ?? '',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return ServiceTile(
                    isGuestUser: isGuestUser,
                    service: filteredServices[index],
                    onFavPressed: () {
                      if (isGuestUser ?? false) {
                        // SignUpAlertForGuestUsers().showSignUpAlert(context);
                      } else {
                        // setFavorite(filteredServices[index]);
                      }
                    },
                  );
                }, childCount: filteredServices.length),
              ),
              SliverToBoxAdapter(child: SizedBox(height: safePadding.bottom)),
            ],
          ),
        );
      },
    );
  }

  void _filterServices(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<ServiceModel> filtered = allServices;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filtered = filtered.where((service) {
        final query = searchQuery.toLowerCase();
        final serviceName = isArabic
            ? service.name_ar?.toLowerCase() ?? ''
            : service.name?.toLowerCase() ?? '';
        final serviceDescription = service.description?.toLowerCase() ?? '';

        return serviceName.contains(query) ||
            serviceDescription.contains(query);
      }).toList();
    }

    if (hasActiveFilter) {
      filtered = filtered.where((service) {
        final ratingCount = service.ratingCount ?? 0;
        final totalRating = service.totalRating ?? 0.0;
        final avgRating = ratingCount == 0 ? 0.0 : totalRating / ratingCount;

        final matchesRating =
            (selectedRatings?.isEmpty ?? false) ||
            (selectedRatings?.contains(avgRating.round()) ?? false);

        final matchesPrice =
            (selectedPriceRanges?.isEmpty ?? false) ||
            (selectedPriceRanges?.any(
                  (index) =>
                      _isInPriceRange(index, service.price?.toDouble() ?? 0.0),
                ) ??
                false);

        return matchesRating && matchesPrice;
      }).toList();
    }

    filteredServices = filtered;
  }

  void _openFilter() async {
    final result = await showFilterBottomSheet(
      context,
      selectedDistricts: selectedDistricts,
      selectedPriceRanges: selectedPriceRanges,
      selectedRatings: selectedRatings,
    );
    if (result != null) {
      selectedDistricts = result['districts'] as Set<String>;
      selectedRatings = result['ratings'] as Set<int>;
      selectedPriceRanges = result['prices'] as Set<int>;
      hasActiveFilter = result['isFiltered'] as bool? ?? false;
      _applyFilters();
      setState(() {});
    }
  }

  bool _isInPriceRange(int index, double? price) {
    if (price == null) return false;
    switch (index) {
      case 0:
        return price < 50;
      case 1:
        return price >= 50 && price <= 100;
      case 2:
        return price > 100 && price <= 150;
      case 3:
        return price > 150 && price <= 200;
      case 4:
        return price > 200;
      default:
        return false;
    }
  }
}
