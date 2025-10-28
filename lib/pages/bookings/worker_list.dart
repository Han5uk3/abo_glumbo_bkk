import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/worker_card.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';

enum FilterType { rating, distance, completedOrders }

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

  @override
  void initState() {
    super.initState();

    _fetchcategory();
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

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<List<WorkerWithStats>> _applySearchAndFilters(
    List<WorkerWithStats> workers,
    String searchQuery,
    Set<FilterType> selectedFilters,
  ) async {
    // Show filtering animation
    _isFilteringNotifier.value = true;

    // Simulate processing time for smooth animation
    await Future.delayed(const Duration(milliseconds: 600));

    // First, apply search filter
    List<WorkerWithStats> searchResults = workers;

    if (searchQuery.isNotEmpty) {
      searchResults = workers.where((workerData) {
        final worker = workerData.worker;
        final name = worker.name?.toLowerCase() ?? '';
        final jobRoles = worker.jobRoles ?? [];
        final searchLower = searchQuery.toLowerCase();

        // Check if name matches
        final nameMatches = name.contains(searchLower);

        // Check if any job role matches
        final jobRoleMatches = jobRoles.any(
          (role) => role.toLowerCase().contains(searchLower),
        );

        return nameMatches || jobRoleMatches;
      }).toList();
    }

    // Then, apply sorting based on filters
    final sortedWorkers = List<WorkerWithStats>.from(searchResults);

    if (selectedFilters.isEmpty) {
      // Default sorting: Rating first, then Distance
      sortedWorkers.sort((a, b) {
        final ratingA = a.rating;
        final ratingB = b.rating;
        int ratingComparison = ratingB.compareTo(ratingA);

        if (ratingComparison != 0) {
          return ratingComparison;
        }

        if (widget.selectedAddress != null) {
          final distanceA = calculateDistance(
            a.worker.liveLocation?.latitude ?? 0.0,
            a.worker.liveLocation?.longitude ?? 0.0,
            widget.selectedAddress!.lat ?? 0.0,
            widget.selectedAddress!.lon ?? 0.0,
          );
          final distanceB = calculateDistance(
            b.worker.liveLocation?.latitude ?? 0.0,
            b.worker.liveLocation?.longitude ?? 0.0,
            widget.selectedAddress!.lat ?? 0.0,
            widget.selectedAddress!.lon ?? 0.0,
          );
          return distanceA.compareTo(distanceB);
        }
        return 0;
      });
    } else {
      sortedWorkers.sort((a, b) {
        if (selectedFilters.contains(FilterType.rating)) {
          final ratingA = a.rating;
          final ratingB = b.rating;
          int ratingComparison = ratingB.compareTo(ratingA);
          if (ratingComparison != 0) {
            return ratingComparison;
          }
        }

        if (selectedFilters.contains(FilterType.distance) &&
            widget.selectedAddress != null) {
          final addressLat = widget.selectedAddress!.lat ?? 0.0;
          final addressLon = widget.selectedAddress!.lon ?? 0.0;

          final distanceA = calculateDistance(
            a.worker.liveLocation?.latitude ?? 0.0,
            a.worker.liveLocation?.longitude ?? 0.0,
            addressLat,
            addressLon,
          );
          final distanceB = calculateDistance(
            b.worker.liveLocation?.latitude ?? 0.0,
            b.worker.liveLocation?.longitude ?? 0.0,
            addressLat,
            addressLon,
          );
          int distanceComparison = distanceA.compareTo(distanceB);
          if (distanceComparison != 0) {
            return distanceComparison;
          }
        }

        if (selectedFilters.contains(FilterType.completedOrders)) {
          final ordersA = a.completedJobs;
          final ordersB = b.completedJobs;
          return ordersB.compareTo(ordersA);
        }

        return 0;
      });
    }

    _isFilteringNotifier.value = false;
    return sortedWorkers;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                return const Center(child: Text("An error occurred"));
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
                : AppLocalizations.of(context)!.noWorkersFound,
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
  late AnimationController _animationController;
  final List<Animation<double>> _itemAnimations = [];

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

  String _getFilterLabel(FilterType filter) {
    switch (filter) {
      case FilterType.rating:
        return 'Highest Rating';
      case FilterType.distance:
        return 'Nearest';
      case FilterType.completedOrders:
        return 'Most Orders';
    }
  }

  IconData _getFilterIcon(FilterType filter) {
    switch (filter) {
      case FilterType.rating:
        return Icons.star_rounded;
      case FilterType.distance:
        return Icons.location_on_rounded;
      case FilterType.completedOrders:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: FilterType.values.map((filter) {
          final isSelected = selectedFilters.contains(filter);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_getFilterLabel(filter)),
              selected: isSelected,
              onSelected: (bool selected) {
                final newFilters = Set<FilterType>.from(selectedFilters);
                if (selected) {
                  newFilters.add(filter);
                } else {
                  newFilters.remove(filter);
                }
                onFilterChanged(newFilters);
              },
              avatar: Icon(
                _getFilterIcon(filter),
                size: 18,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
