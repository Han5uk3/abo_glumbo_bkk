import 'dart:convert';
import 'dart:developer';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location_selection.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/worker_card.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FilterType { rating, completedOrders }

class WorkerList extends StatefulWidget {
  final ServiceModel service;
  final String category;
  final AddressModel? selectedAddress;
  final ValueNotifier<int?> selectedIndexNotifier;
  final Function(UserModel) onWorkerSelected;

  const WorkerList({
    super.key,
    required this.category,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
    required this.service,
  });

  @override
  State<WorkerList> createState() => _WorkerListState();
}

class _WorkerListState extends State<WorkerList> {
  final ValueNotifier<Set<FilterType>> _selectedFiltersNotifier =
      ValueNotifier<Set<FilterType>>({});
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _isFilteringNotifier = ValueNotifier<bool>(false);

  List<Province> provinces = [];
  Province? selectedProvince;
  Governorate? selectedGovernorate;
  Neighborhood? selectedNeighborhood;
  bool isLoadingLocations = true;

  CustomerModel? customerData;
  bool isLoadingCustomer = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
    _loadLocations();
    _fetchcategory();
  }

  Future<void> _fetchCustomerData() async {
    setState(() => isLoadingCustomer = true);

    try {
      final uid = LocalStoreHelper.getUID();
      if (uid != null) {
        final docSnapshot = await AppFirestore.customersCollectionRef
            .doc(uid)
            .get();

        if (docSnapshot.exists) {
          customerData = CustomerModel.fromJson(
            docSnapshot.data() as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer data: $e');
    } finally {
      setState(() => isLoadingCustomer = false);
    }
  }

  Future<void> _loadLocations() async {
    setState(() => isLoadingLocations = true);
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_locations.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);

      setState(() {
        provinces = jsonData.map((p) => Province.fromJson(p)).toList();
      });

      // ✅ Wait for customer data before preselecting
      while (isLoadingCustomer) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // ✅ Pre-select customer's location from customerData
      if (customerData?.detailedLocation != null) {
        _preselectCustomerLocation(customerData!.detailedLocation!);
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
    } finally {
      setState(() => isLoadingLocations = false);
    }
  }

  // ✅ Pre-select customer's location as default filter
  void _preselectCustomerLocation(DetailedLocationModel location) {
    if (provinces.isEmpty) return;

    final province = provinces.firstWhere(
      (p) => p.provinceId == location.provinceId,
      orElse: () => provinces.first,
    );

    selectedProvince = province;

    if (province.governorates.isNotEmpty) {
      final governorate = province.governorates.firstWhere(
        (g) => g.govId == location.governorateId,
        orElse: () => province.governorates.first,
      );

      selectedGovernorate = governorate;

      if (governorate.neighborhoods.isNotEmpty) {
        selectedNeighborhood = governorate.neighborhoods.firstWhere(
          (n) => n.neighId == location.neighborhoodId,
          orElse: () => governorate.neighborhoods.first,
        );
      }
    }

    setState(() {});
  }

  _fetchcategory() async {
    final category = await AppServices.fetchCategory(widget.category);
    category["name"];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selectedFiltersNotifier.dispose();
    _searchQueryNotifier.dispose();
    _isFilteringNotifier.dispose();
    super.dispose();
  }

  // double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  //   const R = 6371;
  //   final dLat = _toRadians(lat2 - lat1);
  //   final dLon = _toRadians(lon2 - lon1);
  //   final a =
  //       sin(dLat / 2) * sin(dLat / 2) +
  //       cos(_toRadians(lat1)) *
  //           cos(_toRadians(lat2)) *
  //           sin(dLon / 2) *
  //           sin(dLon / 2);
  //   final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  //   return R * c;
  // }

  Future<List<WorkerWithStats>> _applySearchAndFilters(
    List<WorkerWithStats> workers,
    String searchQuery,
    Set<FilterType> selectedFilters,
  ) async {
    _isFilteringNotifier.value = true;
    await Future.delayed(const Duration(milliseconds: 600));

    // 1. Apply location filter (if selected)
    List<WorkerWithStats> locationFiltered = workers;
    // ✅ FIXED: Only filter if a location is selected, otherwise show all
    if (selectedNeighborhood != null) {
      // Filter by neighborhood
      locationFiltered = workers.where((workerData) {
        final workerLocation = workerData.worker.detailedLocation;
        return workerLocation?.neighborhoodId == selectedNeighborhood!.neighId;
      }).toList();
    } else if (selectedGovernorate != null) {
      // Filter by governorate
      locationFiltered = workers.where((workerData) {
        final workerLocation = workerData.worker.detailedLocation;
        return workerLocation?.governorateId == selectedGovernorate!.govId;
      }).toList();
    } else if (selectedProvince != null) {
      // Filter by province
      locationFiltered = workers.where((workerData) {
        final workerLocation = workerData.worker.detailedLocation;
        return workerLocation?.provinceId == selectedProvince!.provinceId;
      }).toList();
    } else {
      // ✅ FIXED: Show all workers when no location filter is applied
      log('No location filter applied - Showing all ${workers.length} workers');
    }

    // 2. Apply search filter
    List<WorkerWithStats> searchResults = locationFiltered;

    if (searchQuery.isNotEmpty) {
      searchResults = locationFiltered.where((workerData) {
        final worker = workerData.worker;
        final name = worker.name?.toLowerCase() ?? '';
        final jobRoles = worker.jobRoles ?? [];
        final searchLower = searchQuery.toLowerCase();

        final nameMatches = name.contains(searchLower);
        final jobRoleMatches = jobRoles.any(
          (role) => role.toLowerCase().contains(searchLower),
        );

        return nameMatches || jobRoleMatches;
      }).toList();
    }

    // 3. Apply sorting
    final sortedWorkers = List<WorkerWithStats>.from(searchResults);

    if (selectedFilters.isEmpty) {
      // ✅ Default: Highest rating, then most jobs
      sortedWorkers.sort((a, b) {
        final ratingComparison = b.rating.compareTo(a.rating);
        if (ratingComparison != 0) return ratingComparison;

        return b.completedJobs.compareTo(a.completedJobs);
      });
    } else {
      sortedWorkers.sort((a, b) {
        if (selectedFilters.contains(FilterType.rating)) {
          final ratingComparison = b.rating.compareTo(a.rating);
          if (ratingComparison != 0) return ratingComparison;
        }

        if (selectedFilters.contains(FilterType.completedOrders)) {
          return b.completedJobs.compareTo(a.completedJobs);
        }

        return 0;
      });
    }

    _isFilteringNotifier.value = false;
    return sortedWorkers;
  }

  // double _toRadians(double degree) {
  //   return degree * pi / 180;
  // }

  void _showLocationFilterDialog() {
    final isArabic = AppLocalizations.of(context)?.localeName == 'ar';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.filterByLocation ??
                              'Filter by Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedProvince = null;
                                  selectedGovernorate = null;
                                  selectedNeighborhood = null;
                                });
                                setState(() {});
                                Navigator.pop(context);
                              },
                              child: Text(
                                AppLocalizations.of(context)?.clearFilter ??
                                    'Clear',
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        // Province Dropdown
                        _buildLocationDropdown<Province>(
                          label:
                              AppLocalizations.of(context)?.province ??
                              'Province',
                          value: selectedProvince,
                          items: provinces,
                          itemLabel: (province) => province.getName(isArabic),
                          onChanged: (province) {
                            setModalState(() {
                              selectedProvince = province;
                              selectedGovernorate = null;
                              selectedNeighborhood = null;
                            });
                          },
                        ),

                        if (selectedProvince != null) ...[
                          SizedBox(height: 16),

                          // Governorate Dropdown
                          _buildLocationDropdown<Governorate>(
                            label: AppLocalizations.of(context)?.city ?? 'City',
                            value: selectedGovernorate,
                            items: selectedProvince!.governorates,
                            itemLabel: (gov) => gov.getName(isArabic),
                            onChanged: (gov) {
                              setModalState(() {
                                selectedGovernorate = gov;
                                selectedNeighborhood = null;
                              });
                            },
                          ),
                        ],

                        if (selectedGovernorate != null) ...[
                          SizedBox(height: 16),

                          // Neighborhood Dropdown
                          _buildLocationDropdown<Neighborhood>(
                            label:
                                AppLocalizations.of(context)?.neighbourhood ??
                                'Neighborhood',
                            value: selectedNeighborhood,
                            items: selectedGovernorate!.neighborhoods,
                            itemLabel: (neigh) => neigh.getName(isArabic),
                            onChanged: (neigh) {
                              setModalState(() {
                                selectedNeighborhood = neigh;
                              });
                            },
                          ),
                        ],

                        SizedBox(height: 24),

                        // Apply Button
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)?.apply ?? 'Apply',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    );
  }

  // ✅ Get current location filter label
  String _getLocationFilterLabel() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    if (selectedNeighborhood != null) {
      return selectedNeighborhood!.getName(isArabic);
    } else if (selectedGovernorate != null) {
      return selectedGovernorate!.getName(isArabic);
    } else if (selectedProvince != null) {
      return selectedProvince!.getName(isArabic);
    }
    return AppLocalizations.of(context)?.selectLocation ?? 'Select Location';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show loading while fetching customer data
    if (isLoadingCustomer || isLoadingLocations) {
      return Center(child: Loader());
    }
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _showLocationFilterDialog,
            icon: Icon(Icons.location_on_rounded, size: 20),
            label: Text(
              _getLocationFilterLabel(),
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedProvince != null
                  ? AppColors.primary
                  : Colors.grey.shade200,
              foregroundColor: selectedProvince != null
                  ? Colors.white
                  : Colors.black87,
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Filter Chips Section
        SizedBox(
          width: double.infinity,
          height: 80,
          child: ValueListenableBuilder<Set<FilterType>>(
            valueListenable: _selectedFiltersNotifier,
            builder: (context, selectedFilters, child) {
              return FilterChipsSection(
                selectedFilters: selectedFilters,
                onFilterChanged: (Set<FilterType> newFilters) {
                  _selectedFiltersNotifier.value = newFilters;
                },
              );
            },
          ),
        ),

        // Search Section
        _SearchSection(
          controller: _searchController,
          searchQueryNotifier: _searchQueryNotifier,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            style: TextStyle(fontSize: 14, color: Colors.black45),
            AppLocalizations.of(
              context,
            )!.inspectionFeeNote(widget.service.price.toString()),
          ),
        ),

        // Workers List
        Expanded(
          child: StreamBuilder<List<WorkerWithStats>>(
            stream: AppServices.getWorkersByRolesWithStatsRealtime(
              widget.category,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _FilteringAnimation();
              }

              if (snapshot.hasError) {
                debugPrint("Debug - Stream Error: ${snapshot.error}");
                return Center(
                  child: Text(
                    "${AppLocalizations.of(context)!.error}: ${snapshot.error}",
                  ),
                );
              }

              final data = List<WorkerWithStats>.from(snapshot.data ?? []);

              return ValueListenableBuilder<String>(
                valueListenable: _searchQueryNotifier,
                builder: (context, searchQuery, _) {
                  return ValueListenableBuilder<Set<FilterType>>(
                    valueListenable: _selectedFiltersNotifier,
                    builder: (context, selectedFilters, _) {
                      return FutureBuilder<List<WorkerWithStats>>(
                        future: _applySearchAndFilters(
                          data,
                          searchQuery,
                          selectedFilters,
                        ),
                        builder: (context, filterSnapshot) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isFilteringNotifier,
                            builder: (context, isFiltering, _) {
                              if (isFiltering) {
                                return const _FilteringAnimation();
                              }

                              final filteredWorkers = filterSnapshot.data ?? [];

                              if (filteredWorkers.isEmpty) {
                                return _EmptyState(searchQuery: searchQuery);
                              }

                              return _WorkerListView(
                                key: ValueKey(
                                  '${searchQuery}_${selectedFilters.length}',
                                ),
                                service: widget.service,
                                workers: filteredWorkers,
                                selectedAddress: widget.selectedAddress,
                                selectedIndexNotifier:
                                    widget.selectedIndexNotifier,
                                onWorkerSelected: widget.onWorkerSelected,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Animated filtering state widget
class _FilteringAnimation extends StatefulWidget {
  const _FilteringAnimation();

  @override
  State<_FilteringAnimation> createState() => _FilteringAnimationState();
}

class _FilteringAnimationState extends State<_FilteringAnimation>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: const [
                        Colors.white24,
                        Colors.white38,
                        Colors.white24,
                      ],
                      stops: [0.0, _shimmerController.value, 1.0],
                      transform: GradientRotation(
                        _shimmerController.value * 2 * pi,
                      ),
                    ).createShader(bounds);
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 16,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 12,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 12,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(4),
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
              ),
            );
          },
        );
      },
    );
  }
}

// Search Section
class _SearchSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueNotifier<String> searchQueryNotifier;

  const _SearchSection({
    required this.controller,
    required this.searchQueryNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ValueListenableBuilder<String>(
        valueListenable: searchQueryNotifier,
        builder: (context, searchQuery, _) {
          return TextField(
            controller: controller,
            onChanged: (value) {
              searchQueryNotifier.value = value;
            },
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchTechnicians,
              prefixIcon: Icon(Icons.search, color: AppColors.primary),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        searchQueryNotifier.value = '';
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  final String searchQuery;

  const _EmptyState({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty
                ? AppLocalizations.of(
                    context,
                  )!.noTechniciansFoundMatchingYourSearch
                : AppLocalizations.of(context)!.noTechniciansFound,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"$searchQuery"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Worker List View with staggered animation
class _WorkerListView extends StatefulWidget {
  final ServiceModel service;
  final List<WorkerWithStats> workers;
  final AddressModel? selectedAddress;
  final ValueNotifier<int?> selectedIndexNotifier;
  final Function(UserModel) onWorkerSelected;

  const _WorkerListView({
    super.key,
    required this.workers,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
    required this.service,
  });

  @override
  State<_WorkerListView> createState() => _WorkerListViewState();
}

class _WorkerListViewState extends State<_WorkerListView>
    with SingleTickerProviderStateMixin {
  Map<String, Map<String, String>> workerLocalizedRoles =
      {}; // categoryId -> {name, name_ar}
  late AnimationController _animationController;
  final List<Animation<double>> _itemAnimations = [];
  bool _isLoadingCategories = true;

  Map<String, String> jobRoleToCategoryId = {}; // jobRole -> categoryId
  Map<String, Map<String, String>> categoryIdToNames =
      {}; // categoryId -> {name, name_ar}

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100 * widget.workers.length),
    );

    for (int i = 0; i < widget.workers.length; i++) {
      final start = (i / widget.workers.length).clamp(0.0, 1.0);
      final end = ((i + 1) / widget.workers.length).clamp(0.0, 1.0);

      _itemAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
    }

    _animationController.forward();
    _loadCategoryNames();
  }

  Future<void> _loadCategoryNames() async {
    // 1. Collect all unique job roles from all workers
    Set<String> allJobRoles = {};
    for (var workerStat in widget.workers) {
      if (workerStat.worker.jobRoles != null) {
        allJobRoles.addAll(workerStat.worker.jobRoles!);
      }
    }

    if (allJobRoles.isEmpty) {
      setState(() => _isLoadingCategories = false);
      return;
    }

    // 2. Get category IDs for all job roles in parallel
    List<String> jobRolesList = allJobRoles.toList();
    List<Future<String?>> categoryIdFutures = jobRolesList
        .map((role) => AppServices.getCategoryIdByJobRoleOnce(role))
        .toList();

    List<String?> categoryIdResults = await Future.wait(categoryIdFutures);

    // 3. Create jobRole -> categoryId mapping (THIS IS CRITICAL)
    Map<String, String> roleToIdMap = {};
    for (int i = 0; i < jobRolesList.length; i++) {
      if (categoryIdResults[i] != null) {
        roleToIdMap[jobRolesList[i]] = categoryIdResults[i]!;
      }
    }

    // 4. Get unique category IDs
    Set<String> uniqueCategoryIds = roleToIdMap.values.toSet();

    if (uniqueCategoryIds.isEmpty) {
      setState(() => _isLoadingCategories = false);
      return;
    }

    // 5. Batch fetch all categories
    List<CategoryModel> categories = await AppServices.getCategoriesByIds(
      uniqueCategoryIds.toList(),
    );

    // 6. Create categoryId -> names mapping
    Map<String, Map<String, String>> idToNamesMap = {};
    for (var category in categories) {
      if (category.id != null) {
        idToNamesMap[category.id!] = {
          'name': category.name ?? '',
          'name_ar': category.name_ar ?? category.name ?? '',
        };
      }
    }

    if (mounted) {
      setState(() {
        jobRoleToCategoryId = roleToIdMap;
        categoryIdToNames = idToNamesMap;
        _isLoadingCategories = false;
      });
    }
  }

  List<String> _getLocalizedRoles(UserModel worker) {
    bool isArabic = Directionality.of(context) == TextDirection.rtl;
    List<String> localizedRoles = [];

    for (var role in worker.jobRoles ?? []) {
      String localizedName = role; // Fallback to original role name

      // Get category ID for THIS SPECIFIC job role
      String? categoryId = jobRoleToCategoryId[role];

      if (categoryId != null) {
        // Get localized name from category
        Map<String, String>? categoryNames = categoryIdToNames[categoryId];

        if (categoryNames != null) {
          if (isArabic && categoryNames['name_ar']!.isNotEmpty) {
            localizedName = categoryNames['name_ar']!;
          } else if (categoryNames['name']!.isNotEmpty) {
            localizedName = categoryNames['name']!;
          }
        }
      }

      localizedRoles.add(localizedName);
    }

    return localizedRoles;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: widget.workers.length,
      itemBuilder: (context, index) {
        final statData = widget.workers[index];

        return AnimatedBuilder(
          animation: _itemAnimations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - _itemAnimations[index].value)),
              child: Opacity(
                opacity: _itemAnimations[index].value,
                child: child,
              ),
            );
          },
          child: ValueListenableBuilder<int?>(
            valueListenable: widget.selectedIndexNotifier,
            builder: (context, selectedIndex, child) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  widget.selectedIndexNotifier.value = index;
                  widget.onWorkerSelected(statData.worker);
                },
                child: WorkerCard(
                  reviewCount: statData.reviewCount,
                  service: widget.service,
                  rating: statData.rating,
                  completedJobs: statData.completedJobs,
                  worker: statData.worker,
                  customerAddress:
                      widget.selectedAddress ??
                      AddressModel(
                        id: '',
                        fullName: '',
                        buildingNumber: '',
                        phoneNumber: '',
                      ),
                  isSelected: isSelected,
                  localizedJobRoles: _getLocalizedRoles(
                    statData.worker,
                  ), // Pass localized names
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Filter Chips Section
class FilterChipsSection extends StatelessWidget {
  final Set<FilterType> selectedFilters;
  final Function(Set<FilterType>) onFilterChanged;

  const FilterChipsSection({
    super.key,
    required this.selectedFilters,
    required this.onFilterChanged,
  });

  String _getFilterLabel(FilterType filter, BuildContext context) {
    switch (filter) {
      case FilterType.rating:
        return AppLocalizations.of(context)!.highestRating;
      case FilterType.completedOrders:
        return AppLocalizations.of(context)!.mostOrders;
    }
  }

  IconData _getFilterIcon(FilterType filter) {
    switch (filter) {
      case FilterType.rating:
        return Icons.star_rounded;
      case FilterType.completedOrders:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: FilterType.values.map((filter) {
          final isSelected = selectedFilters.contains(filter);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: filter == FilterType.rating ? 8 : 0,
                left: filter == FilterType.completedOrders ? 8 : 0,
              ),
              child: InkWell(
                onTap: () {
                  final newFilters = Set<FilterType>.from(selectedFilters);
                  if (isSelected) {
                    newFilters.remove(filter);
                  } else {
                    newFilters.add(filter);
                  }
                  onFilterChanged(newFilters);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFilterIcon(filter),
                        size: 20,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getFilterLabel(filter, context),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
