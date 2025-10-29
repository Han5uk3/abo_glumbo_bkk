// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Singleton class to manage locations cache
class LocationsCache {
  static final LocationsCache _instance = LocationsCache._internal();
  factory LocationsCache() => _instance;
  LocationsCache._internal();

  List<LocationModel>? _locations;
  bool _isLoading = false;

  Future<List<LocationModel>> getLocations(BuildContext context) async {
    if (_locations != null) {
      return _locations!;
    }

    if (_isLoading) {
      // Wait for the current loading to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _locations ?? [];
    }

    _isLoading = true;
    try {
      var response = await AppFirestore.locationsCollectionRef.get();
      final currentLanguage = AppLocalizations.of(context)?.localeName ?? 'en';
      final isArabic = currentLanguage == 'ar';

      List<LocationModel> allLocations = response.docs
          .map((e) => LocationModel.fromQuerySnapshot(e))
          .toList();

      Map<String, LocationModel> uniqueLocations = {};

      for (LocationModel location in allLocations) {
        final displayName = isArabic
            ? (location.name_ar ?? location.name ?? '')
            : (location.name ?? '');

        if (displayName.isNotEmpty) {
          uniqueLocations[displayName.toLowerCase()] = location;
        }
      }

      _locations = uniqueLocations.values.toList();

      _locations!.sort((a, b) {
        final aName = isArabic ? (a.name_ar ?? a.name ?? '') : (a.name ?? '');
        final bName = isArabic ? (b.name_ar ?? b.name ?? '') : (b.name ?? '');
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

      return _locations!;
    } catch (e) {
      return [];
    } finally {
      _isLoading = false;
    }
  }

  void clearCache() {
    _locations = null;
  }
}

Future<Map<String, dynamic>?> showFilterBottomSheet(
  BuildContext context, {
  Set<String>? selectedDistricts,
  Set<int>? selectedRatings,
  Set<int>? selectedPriceRanges,
  Set<String>? selectedCategories,
  bool isFromSearchPage = false,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FilterBottomSheet(
        selectedDistricts: selectedDistricts ?? {},
        selectedRatings: selectedRatings ?? {},
        selectedPriceRanges: selectedPriceRanges ?? {},
        selectedCategories: selectedCategories ?? {},
        isFromSearchPage: isFromSearchPage,
      );
    },
  );
}

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.selectedDistricts,
    required this.selectedRatings,
    required this.selectedPriceRanges,
    required this.selectedCategories,
    this.isFromSearchPage = false,
  });

  final Set<String> selectedDistricts;
  final Set<int> selectedRatings;
  final Set<int> selectedPriceRanges;
  final Set<String> selectedCategories;
  final bool isFromSearchPage;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  int selectedFilterIndex = 0;
  Set<int> selectedRatings = {};
  Set<int> selectedPriceRanges = {};
  Set<String> selectedDistricts = {};
  Set<String> selectedCategories = {};
  List<LocationModel> locations = [];
  List<CategoryModel> categories = [];
  bool isLoading = false;
  final LocationsCache _locationsCache = LocationsCache();

  @override
  void initState() {
    selectedDistricts = {...widget.selectedDistricts};
    selectedRatings = {...widget.selectedRatings};
    selectedPriceRanges = {...widget.selectedPriceRanges};
    loadLocations();
    if (widget.isFromSearchPage) {
      selectedCategories = {...widget.selectedCategories};
      loadCategories();
    }
    super.initState();
  }

  Future loadLocations() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final cachedLocations = await _locationsCache.getLocations(context);
      if (mounted) {
        setState(() {
          locations = cachedLocations;
        });
      }
    } catch (e) {
      debugPrint('Failed to load locations: $e');
      if (mounted) {
        // Set empty locations list to prevent further errors
        setState(() {
          locations = [];
        });

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load locations. Location filters may not be available.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future loadCategories() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final categories = await AppFirestore.categoriesCollectionRef
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          this.categories = categories.docs
              .map((doc) => CategoryModel.fromQuerySnapshot(doc))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
      if (mounted) {
        // Set empty categories list to prevent further errors
        setState(() {
          categories = [];
        });

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load categories. Some filters may not be available.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  List<Map<String, String>> getPriceFilterItems(BuildContext context) {
    return [
      {'label': AppLocalizations.of(context)!.lessthan50SAR},
      {'label': AppLocalizations.of(context)!.fiftySARto100SAR},
      {'label': AppLocalizations.of(context)!.hundredSARto150SAR},
      {'label': AppLocalizations.of(context)!.onefiftySARto200SAR},
      {'label': AppLocalizations.of(context)!.morethan200SAR},
    ];
  }

  void _clearAllFilters() {
    Navigator.pop(context, {
      'districts': <String>{},
      'ratings': <int>{},
      'prices': <int>{},
      'categories': <String>{},
      'isFiltered': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.tune, color: AppColors.secondary, size: 24),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)?.filter ?? 'Filter',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(
                      width: 160,
                      height: double.maxFinite,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          right: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildFilterCategoryTile(
                            icon: Icons.location_on_outlined,
                            title:
                                AppLocalizations.of(context)?.district ??
                                'District',
                            isSelected: selectedFilterIndex == 1,
                            onTap: () {
                              if (mounted)
                                setState(() => selectedFilterIndex = 1);
                            },
                          ),
                          _buildFilterCategoryTile(
                            icon: Icons.star_outline,
                            title:
                                AppLocalizations.of(context)?.rating ??
                                'Rating',
                            isSelected: selectedFilterIndex == 2,
                            onTap: () {
                              if (mounted)
                                setState(() => selectedFilterIndex = 2);
                            },
                          ),
                          _buildFilterCategoryTile(
                            icon: Icons.payments_outlined,
                            title:
                                AppLocalizations.of(context)?.price ?? 'Price',
                            isSelected: selectedFilterIndex == 3,
                            onTap: () {
                              if (mounted)
                                setState(() => selectedFilterIndex = 3);
                            },
                          ),
                          if (widget.isFromSearchPage) ...{
                            _buildFilterCategoryTile(
                              icon: Icons.category_outlined,
                              title:
                                  AppLocalizations.of(context)?.categories ??
                                  'Categories',
                              isSelected: selectedFilterIndex == 4,
                              onTap: () {
                                if (mounted)
                                  setState(() => selectedFilterIndex = 4);
                              },
                            ),
                          },
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: _buildFilterContent(),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + safePadding.bottom,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextButton(
                              onPressed: _clearAllFilters,
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.clear ?? 'Clear',
                                style: GoogleFonts.dmSans(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.secondary,
                                  AppColors.secondary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context, {
                                  'districts': selectedDistricts,
                                  'ratings': selectedRatings,
                                  'prices': selectedPriceRanges,
                                  'categories': widget.isFromSearchPage
                                      ? selectedCategories
                                      : null,
                                  'isFiltered': true,
                                });
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.filter ??
                                    'Apply Filter',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCategoryTile({
    required IconData icon,
    required String title,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.secondary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.secondary : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.secondary : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.secondary : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContent() {
    final safePadding = MediaQuery.of(context).padding;

    switch (selectedFilterIndex) {
      case 1:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: 100 + safePadding.bottom),
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      final location = locations[index];
                      final currentLanguage =
                          AppLocalizations.of(context)?.localeName ?? 'en';
                      final isArabic = currentLanguage == 'ar';
                      final displayName = isArabic
                          ? (location.name_ar ?? location.name ?? '')
                          : (location.name ?? '');
                      final isSelected = selectedDistricts.contains(
                        location.id!,
                      );

                      return CheckboxListTile(
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.secondary
                              : Colors.grey[700]!,
                          width: 1,
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedDistricts.add(location.id!);
                            } else {
                              selectedDistricts.remove(location.id!);
                            }
                          });
                        },
                        title: Text(
                          displayName,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.secondary
                                : Colors.black87,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );

      case 2:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 100 + safePadding.bottom),
            itemCount: 5,
            itemBuilder: (context, index) {
              final rating = 5 - index;
              final isSelected = selectedRatings.contains(rating);

              return CheckboxListTile(
                side: BorderSide(
                  color: isSelected ? AppColors.secondary : Colors.grey[700]!,
                  width: 1,
                ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedRatings.add(rating);
                    } else {
                      selectedRatings.remove(rating);
                    }
                  });
                },
                title: Row(
                  children: [
                    ...List.generate(5, (starIndex) {
                      return Icon(
                        starIndex < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 22,
                      );
                    }),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 4,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        );

      case 3:
        final priceItems = getPriceFilterItems(context);
        return Container(
          padding: const EdgeInsets.only(left: 10),
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 100 + safePadding.bottom),
            itemCount: priceItems.length,
            itemBuilder: (context, index) {
              final isSelected = selectedPriceRanges.contains(index);

              return CheckboxListTile(
                side: BorderSide(
                  color: isSelected ? AppColors.secondary : Colors.grey[700]!,
                  width: 1,
                ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedPriceRanges.add(index);
                    } else {
                      selectedPriceRanges.remove(index);
                    }
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.payments,
                      color: isSelected ? Colors.green : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      priceItems[index]['label']!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.green[800] : Colors.black87,
                      ),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 4,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        );
      case 4:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: 100 + safePadding.bottom),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final currentLanguage =
                          AppLocalizations.of(context)?.localeName ?? 'en';
                      final isArabic = currentLanguage == 'ar';
                      final displayName = isArabic
                          ? (category.name_ar ?? category.name ?? '')
                          : (category.name ?? '');
                      final isSelected = selectedCategories.contains(
                        category.id!,
                      );

                      return CheckboxListTile(
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.secondary
                              : Colors.grey[700]!,
                          width: 1,
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedCategories.add(category.id!);
                            } else {
                              selectedCategories.remove(category.id!);
                            }
                          });
                        },
                        title: Text(
                          displayName,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.secondary
                                : Colors.black87,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.selectFilter ??
                    'Select a filter to start',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
    }
  }
}
