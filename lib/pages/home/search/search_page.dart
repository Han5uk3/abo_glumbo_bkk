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

import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query});
  final String? query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String? searchQuery;
  bool isGuestUser = false;
  List<ServiceModel> allServices = [];
  List<ServiceModel> filteredServices = [];
  bool isLoading = false;

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
                AppLocalizations.of(context)?.tryAdjustingYourSearchOrFilters ?? 'Try adjusting your search or filters',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
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
          ),
        ),
      ),
      body: Column(
        children: [
          // Results count display
          if (!isLoading && (searchQuery != null && searchQuery!.isNotEmpty))
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
                    '${filteredServices.length} ${filteredServices.length == 1 ? AppLocalizations.of(context)?.serviceFound ?? 'service found' : AppLocalizations.of(context)?.servicesFound ?? 'services found'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                    : (searchQuery == null || searchQuery!.trim().isEmpty)
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
