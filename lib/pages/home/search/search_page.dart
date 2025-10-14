import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/categories/bloc/categories_bloc.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/sheets/filter.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query});
  final String? query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String? searchQuery;
  bool isGuestUser = false;
  List<ServiceModel> allServices = [];
  List<ServiceModel> filteredServices = [];
  Set<String>? selectedDistricts;
  Set<int>? selectedRatings;
  Set<int>? selectedPriceRanges;
  Set<String>? selectedCategories;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  bool _hasActiveFilters = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (widget.query != null) {
        setState(() {
          searchQuery = widget.query;
          _searchController.text = widget.query!;
        });
      }
      _checkUserGuestStatus();
      context.read<CategoriesBloc>().add(LoadCategories());
      _fetchServices();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkUserGuestStatus() async {
    final isGuest = LocalStoreHelper.getGuestUser();
    setState(() {
      isGuestUser = isGuest;
    });

    // Load user data after setting guest status
    if (!isGuest) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final uid = LocalStoreHelper.getUID();
    if (uid != null && !isGuestUser) {
      // Load customer data for favorite functionality
      context.read<AccountBloc>().add(ListenCustomerData(uid: uid));
    }
  }

  Future<void> _fetchServices() async {
    if (!mounted) return;

    try {
      setState(() {
        isLoading = true;
      });

      final categoriesState = context.read<CategoriesBloc>().state;
      List<CategoryModel> categories = [];

      if (categoriesState is CategoriesLoaded) {
        categories = categoriesState.categories;
      }

      // Fetch services from AppFirestore with timeout
      final querySnapshot = await AppFirestore.servicesCollectionRef
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Request timed out',
              const Duration(seconds: 30),
            ),
          );

      if (!mounted) return;

      allServices = querySnapshot.docs
          .map((doc) {
            try {
              final service = ServiceModel.fromQueryDocumentSnapshot(doc);

              // Only use copyWith if we have categories loaded and service is valid
              if (categories.isNotEmpty && service.id != null) {
                return service.copyWith(categories: categories);
              } else {
                return service;
              }
            } catch (e) {
              debugPrint('Error parsing service from document ${doc.id}: $e');
              // Return null for invalid services, we'll filter them out
              return null;
            }
          })
          .where((service) => service != null && service.id != null)
          .cast<ServiceModel>()
          .toList();

      if (mounted) {
        _applyFilters();
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching services: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          allServices = [];
          filteredServices = [];
        });

        String errorMessage = 'Failed to load services';
        if (e is TimeoutException) {
          errorMessage = 'Request timed out. Please check your connection';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: AppLocalizations.of(context)?.retry ?? 'Retry',
              textColor: Colors.white,
              onPressed: _fetchServices,
            ),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;

    List<ServiceModel> filtered = List.from(allServices);
    final currentLocale = Localizations.localeOf(context);
    final languageCode = currentLocale.languageCode;

    // Apply search query filter
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
      final query = searchQuery!.trim().toLowerCase();

      filtered = filtered.where((service) {
        // Ensure service has valid data
        if (service.id == null) return false;

        // Get service name based on current language
        final serviceName =
            (service.nameLocalized(languageCode: languageCode) ?? '')
                .toLowerCase()
                .trim();
        final serviceNameEn = (service.name ?? '').toLowerCase().trim();
        final serviceNameAr = (service.name_ar ?? '').toLowerCase().trim();

        // Get description based on current language
        final serviceDescription =
            (service.descriptionLocalized(languageCode: languageCode) ?? '')
                .toLowerCase()
                .trim();
        final serviceDescriptionEn = (service.description ?? '')
            .toLowerCase()
            .trim();
        final serviceDescriptionAr = (service.description_ar ?? '')
            .toLowerCase()
            .trim();

        // Search in both current language and fallback languages for better results
        return serviceName.contains(query) ||
            serviceDescription.contains(query) ||
            serviceNameEn.contains(query) ||
            serviceNameAr.contains(query) ||
            serviceDescriptionEn.contains(query) ||
            serviceDescriptionAr.contains(query);
      }).toList();
    }

    // Apply additional filters
    if (_hasActiveFilters) {
      filtered = filtered.where((service) {
        // Ensure service has valid data for filtering
        if (service.id == null) return false;

        final ratingCount = service.ratingCount ?? 0;
        final totalRating = service.totalRating ?? 0.0;
        final avgRating = ratingCount == 0 ? 0.0 : totalRating / ratingCount;

        final matchesDistrict =
            (selectedDistricts?.isEmpty ?? true) ||
            (service.locations?.isNotEmpty == true &&
                service.locations!.any(
                  (id) => selectedDistricts?.contains(id) ?? false,
                ));

        final matchesRating =
            (selectedRatings?.isEmpty ?? true) ||
            (selectedRatings?.contains(avgRating.round()) ?? false);

        final matchesPrice =
            (selectedPriceRanges?.isEmpty ?? true) ||
            (selectedPriceRanges?.any(
                  (index) => _isInPriceRange(index, service.price?.toDouble()),
                ) ??
                false);

        final serviceCategory =
            service.category?.toString().trim().toLowerCase() ?? '';
        final matchesCategory =
            (selectedCategories?.isEmpty ?? true) ||
            (serviceCategory.isNotEmpty &&
                selectedCategories
                        ?.map((e) => e.toLowerCase().trim())
                        .contains(serviceCategory) ==
                    true);

        return matchesRating &&
            matchesPrice &&
            matchesCategory &&
            matchesDistrict;
      }).toList();
    }

    if (mounted) {
      setState(() {
        filteredServices = filtered;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          searchQuery = query.trim().isEmpty ? null : query.trim();
          _applyFilters();
        });
      }
    });
  }

  void _openFilter() async {
    try {
      final result = await showFilterBottomSheet(
        context,
        selectedDistricts: selectedDistricts,
        selectedRatings: selectedRatings,
        selectedPriceRanges: selectedPriceRanges,
        selectedCategories: selectedCategories,
        isFromSearchPage: true,
      );

      if (result != null) {
        setState(() {
          selectedDistricts = result['districts'] as Set<String>? ?? {};
          selectedRatings = result['ratings'] as Set<int>? ?? {};
          selectedPriceRanges = result['prices'] as Set<int>? ?? {};
          selectedCategories = result['categories'] as Set<String>? ?? {};
          _hasActiveFilters = result['isFiltered'] as bool? ?? false;
        });
        _applyFilters();
      }
    } catch (e) {
      // Handle any errors when showing the filter
      debugPrint('Filter error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open filter. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _openFilter,
            ),
          ),
        );
      }
    }
  }

  Future<void> _setFavorite(ServiceModel service) async {
    if (isGuestUser) {
      SignUpAlertForGuestUsers().showSignUpAlert(context);
      return;
    }

    // Check if service ID is valid
    if (service.id == null || service.id!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.error ?? 'Service ID is missing',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final accountState = context.read<AccountBloc>().state;
    if (accountState is CustomerDataLoaded) {
      context.read<AccountBloc>().add(ToggleFavoriteService(service: service));
    } else {
      // User data not loaded, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.error ?? 'Please login first',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isInPriceRange(int index, double? price) {
    if (price == null || price < 0) return false;

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

  Widget _buildEmptySearchState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.startTyping,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.noServicesFound,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Text(
                'Try adjusting your search or filters',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              if (_hasActiveFilters)
                ElevatedButton.icon(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        selectedDistricts = null;
                        selectedRatings = null;
                        selectedPriceRanges = null;
                        selectedCategories = null;
                        _hasActiveFilters = false;
                      });
                      _applyFilters();
                    }
                  },
                  icon: const Icon(Icons.clear),
                  label: Text(
                    AppLocalizations.of(context)?.reset ?? 'Clear Filters',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesList() {
    if (filteredServices.isEmpty) {
      return _buildNoResultsState();
    }

    return ListView.builder(
      itemCount: filteredServices.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final service = filteredServices[index];

        // Additional safety check
        if (service.id == null) {
          return const SizedBox.shrink();
        }

        return ServiceTile(
          isfromHome: false,
          isGuestUser: isGuestUser,
          service: service,
          onFavPressed: () => _setFavorite(service),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        primary: true,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.all(16.0).copyWith(top: 8),
          child: SearchBar(
            controller: _searchController,
            hintText: AppLocalizations.of(context)?.searchServices ?? '',
            textInputAction: TextInputAction.search,
            autoFocus: true,
            onChanged: _onSearchChanged,
            leading: BackButton(
              color: Colors.black87,
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
              },
            ),
            trailing: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _hasActiveFilters
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                    onPressed: _openFilter,
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Results count display
          if (!isLoading &&
              (searchQuery != null && searchQuery!.isNotEmpty ||
                  _hasActiveFilters))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${filteredServices.length} ${filteredServices.length == 1 ? 'service found' : 'services found'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt,
                            size: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)?.filtered ??
                                'Filtered',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: BlocListener<AccountBloc, AccountState>(
              listenWhen: (previous, current) {
                // Only listen to actual errors, not updating states
                return current is FavoriteServiceError;
              },
              listener: (context, state) {
                if (state is FavoriteServiceError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${AppLocalizations.of(context)?.error ?? 'Error'}: ${state.error}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: RefreshIndicator(
                onRefresh: _fetchServices,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (searchQuery == null || searchQuery!.trim().isEmpty) &&
                          !_hasActiveFilters
                    ? _buildEmptySearchState()
                    : _buildServicesList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
