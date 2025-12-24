import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location_selection.dart';
import 'package:abo_glumbo_bbk/models/searchable_dropdown.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/worker_card.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FilterType { rating, completedOrders }

class WorkerList extends StatefulWidget {
  final ServiceModel service;
  final String category;
  final AddressModel? selectedAddress;
  final ValueNotifier<int?> selectedIndexNotifier;
  final Function(UserModel) onWorkerSelected;
  final DateTime selectedDate;
  final Map timeSlot;

  const WorkerList({
    super.key,
    required this.category,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
    required this.service,
    required this.selectedDate,
    required this.timeSlot,
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

  List<Region> regions = [];
  Region? selectedRegion;
  City? selectedCity;
  District? selectedDistrict;
  bool isLoadingLocations = true;

  CustomerModel? customerData;
  bool isLoadingCustomer = true;

  late Stream<List<WorkerWithStats>> _workersStream;

  @override
  void initState() {
    super.initState();
    _workersStream = AppServices.getWorkersByRolesWithStatsRealtime(
      widget.category,
    );
    _fetchCustomerData();
    loadLocations();
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

  Future<void> loadLocations() async {
    setState(() {
      isLoadingLocations = true;
    });

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_hierarchical.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);

      if (mounted) {
        setState(() {
          regions = jsonData.map((r) => Region.fromJson(r)).toList();
          isLoadingLocations = false;
        });

        // Pre-select location AFTER regions are loaded and state is set
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (customerData?.detailedLocation != null && mounted) {
            _preselectCustomerLocation(customerData!.detailedLocation!);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading locations: $e');
      }
      if (mounted) {
        setState(() {
          isLoadingLocations = false;
        });
      }
    }
  }

  // ✅ Pre-select customer's location as default filter
  void _preselectCustomerLocation(DetailedLocationModel location) {
    if (regions.isEmpty) return;

    final province = regions.firstWhere(
      (p) => p.regionId == location.regionId,
      orElse: () => regions.first,
    );

    selectedRegion = province;

    if (province.cities.isNotEmpty) {
      final governorate = province.cities.firstWhere(
        (g) => g.cityId == location.cityId,
        orElse: () => province.cities.first,
      );

      selectedCity = governorate;

      if (governorate.districts.isNotEmpty) {
        selectedDistrict = governorate.districts.firstWhere(
          (n) => n.districtId == location.neighborhoodId,
          orElse: () => governorate.districts.first,
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

  List<WorkerWithStats> _applySearchAndFilters(
    List<WorkerWithStats> workers,
    String searchQuery,
    Set<FilterType> selectedFilters,
  ) {
    // 1. Apply location filter (if selected)
    List<WorkerWithStats> locationFiltered = workers;
    // ✅ FIXED: Only filter if a location is selected, otherwise show all
    if (selectedDistrict != null) {
      // Filter by neighborhood
      locationFiltered = workers.where((workerData) {
        final workerLocation = workerData.worker.detailedLocation;

        debugPrint('Worker location: ${workerLocation?.neighborhoodEn}');

        return workerLocation?.neighborhoodId == selectedDistrict!.districtId;
      }).toList();
    } else if (selectedCity != null) {
      // Filter by governorate
      locationFiltered = workers.where((workerData) {
        final workerLocation = workerData.worker.detailedLocation;
        debugPrint('Worker location: ${workerLocation?.cityEn}');
        return workerLocation?.cityId == selectedCity!.cityId;
      }).toList();
    } else if (selectedRegion != null) {
      // Filter by province
      locationFiltered = workers.where((workerData) {
        final workerLocation = workerData.worker.detailedLocation;
        debugPrint('Worker location: ${workerLocation?.regionEn}');

        return workerLocation?.regionId == selectedRegion!.regionId;
      }).toList();
    } else {
      // ✅ FIXED: Show all workers when no location filter is applied
      debugPrint(
        'No location filter applied - Showing all ${workers.length} workers',
      );
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
      enableDrag: false,

      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
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
                                  selectedRegion = null;
                                  selectedCity = null;
                                  selectedDistrict = null;
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
                        _buildDropdownField<Region>(
                          hint: AppLocalizations.of(
                            context,
                          )!.typeProvinceNameToSearch,
                          label:
                              '${AppLocalizations.of(context)?.province ?? 'Region'} *',
                          value: selectedRegion,
                          items: regions,
                          itemLabel: (region) => region.getName(isArabic),
                          onChanged: (region) {
                            setState(() {
                              selectedRegion = region;
                              selectedCity = null;
                              selectedDistrict = null;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return AppLocalizations.of(
                                    context,
                                  )?.pleaseSelectProvince ??
                                  'Please select a region';
                            }
                            return null;
                          },
                        ),

                        if (selectedRegion != null) ...[
                          const SizedBox(height: 16),

                          // ✅ City Dropdown
                          _buildDropdownField<City>(
                            hint: AppLocalizations.of(
                              context,
                            )!.typeCityNameToSearch,

                            label:
                                '${AppLocalizations.of(context)?.city ?? 'City'} *',
                            value: selectedCity,
                            items: selectedRegion!.cities,
                            itemLabel: (city) => city.getName(isArabic),
                            onChanged: (city) {
                              setState(() {
                                selectedCity = city;
                                selectedDistrict = null;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.of(
                                      context,
                                    )?.pleaseSelectCity ??
                                    'Please select a city';
                              }
                              return null;
                            },
                          ),
                        ],

                        if (selectedCity != null) ...[
                          const SizedBox(height: 16),

                          // ✅ District Dropdown
                          _buildDropdownField<District>(
                            hint: AppLocalizations.of(
                              context,
                            )!.typeNeighborhoodNameToSearch,
                            label:
                                '${AppLocalizations.of(context)?.neighbourhood ?? 'District'} *',
                            value: selectedDistrict,
                            items: selectedCity!.districts,
                            itemLabel: (district) => district.getName(isArabic),
                            onChanged: (district) {
                              setState(() {
                                selectedDistrict = district;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.of(
                                      context,
                                    )?.pleaseSelectNeighborhood ??
                                    'Please select a district';
                              }
                              return null;
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

  Widget _buildDropdownField<T extends Object>({
    required String hint,
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return SearchableDropdown<T>(
      hintText: hint,
      label: label,
      value: value,
      items: items,
      itemLabel: itemLabel,
      onChanged: onChanged,
      validator: validator,
    );
  }

  // ✅ Get current location filter label
  String _getLocationFilterLabel() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    if (selectedDistrict != null) {
      return selectedDistrict!.getName(isArabic);
    } else if (selectedCity != null) {
      return selectedCity!.getName(isArabic);
    } else if (selectedRegion != null) {
      return selectedRegion!.getName(isArabic);
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
              backgroundColor: selectedRegion != null
                  ? AppColors.primary
                  : Colors.grey.shade200,
              foregroundColor: selectedRegion != null
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
            stream: _workersStream,
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
                      final filteredWorkers = _applySearchAndFilters(
                        data,
                        searchQuery,
                        selectedFilters,
                      );

                      if (filteredWorkers.isEmpty) {
                        return _EmptyState(
                          searchQuery: searchQuery,
                          onClearFilter: () {
                            _searchController.clear();
                            _searchQueryNotifier.value = '';
                            _selectedFiltersNotifier.value = {};
                            setState(() {
                              selectedRegion = null;
                              selectedCity = null;
                              selectedDistrict = null;
                            });
                          },
                          onChangeLocation: _showLocationFilterDialog,
                        );
                      }

                      return _WorkerListView(
                        key: ValueKey(
                          '${searchQuery}_${selectedFilters.length}',
                        ),
                        service: widget.service,
                        workers: filteredWorkers,
                        selectedAddress: widget.selectedAddress,
                        selectedIndexNotifier: widget.selectedIndexNotifier,
                        onWorkerSelected: widget.onWorkerSelected,
                        selectedDate: widget.selectedDate,
                        timeSlot: widget.timeSlot,
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
  final VoidCallback onClearFilter;
  final VoidCallback onChangeLocation;

  const _EmptyState({
    required this.searchQuery,
    required this.onClearFilter,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty
                    ? AppLocalizations.of(
                        context,
                      )!.noTechniciansFoundMatchingYourSearch
                    : AppLocalizations.of(context)!.noTechniciansFound,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
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
              const SizedBox(height: 12),
              Text(
                "No technicians are available in your area at the moment, please try any of the below actions.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Change Location Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onChangeLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Change Location',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Clear Filter Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onClearFilter,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.clearFilter ?? 'Clear Filter',
                    style: TextStyle(
                      color: AppColors.primary,
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
  final DateTime selectedDate;
  final Map timeSlot;

  const _WorkerListView({
    super.key,
    required this.workers,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
    required this.service,
    required this.selectedDate,
    required this.timeSlot,
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
    _subscribeToBusyAgents();
  }

  Set<String> busyAgentIds = {};
  StreamSubscription? _bookingsSubscription;

  void _subscribeToBusyAgents() {
    try {
      final timeOfDay = widget.timeSlot["time"] as TimeOfDay;
      final bookingDate = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      _bookingsSubscription = AppFirestore.bookingsCollectionRef
          .where('bookingDateTime', isEqualTo: Timestamp.fromDate(bookingDate))
          .snapshots()
          .listen(
            (snapshot) {
              final busyIds = <String>{};
              for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['bookingStatusCode'];
                // Consider busy only if status is Accepted (A)
                if (status == 'A') {
                  final agent = data['agent'];
                  if (agent != null && agent['uid'] != null) {
                    busyIds.add(agent['uid']);
                  }
                }
              }

              if (mounted) {
                setState(() {
                  busyAgentIds = busyIds;
                });
              }
            },
            onError: (e) {
              debugPrint("Error fetching busy agents: $e");
            },
          );
    } catch (e) {
      debugPrint("Error setting up busy agents subscription: $e");
    }
  }

  Future<void> _loadCategoryNames() async {
    try {
      // 1. Collect all unique job roles from all workers
      Set<String> allJobRoles = {};
      for (var workerStat in widget.workers) {
        if (workerStat.worker.jobRoles != null) {
          allJobRoles.addAll(workerStat.worker.jobRoles!);
        }
      }

      if (allJobRoles.isEmpty) {
        if (mounted) setState(() => _isLoadingCategories = false);
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
        if (mounted) setState(() => _isLoadingCategories = false);
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
        });
      }
    } catch (e) {
      debugPrint('Error loading category names: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
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
    _bookingsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) {
      return const _FilteringAnimation();
    }
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
                  if (busyAgentIds.contains(statData.worker.uid)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.technicianIsBusyatThisTime,
                        ),
                      ),
                    );
                    return;
                  }
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
                  isBusy: busyAgentIds.contains(statData.worker.uid),
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
