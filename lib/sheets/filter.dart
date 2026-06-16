// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/location_selection.dart';
import 'package:abo_glumbo_bbk/models/searchable_dropdown.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

// Singleton class to manage locations cache
class LocationsCache {
  static final LocationsCache _instance = LocationsCache._internal();
  factory LocationsCache() => _instance;
  LocationsCache._internal();

  List<Region>? _regions;
  bool _isLoading = false;

  Future<List<Region>> getRegions() async {
    if (_regions != null) {
      return _regions!;
    }

    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _regions ?? [];
    }

    _isLoading = true;
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_hierarchical.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);
      _regions = jsonData.map((r) => Region.fromJson(r)).toList();
      return _regions!;
    } catch (e) {
      debugPrint('Failed to load locations: $e');
      return [];
    } finally {
      _isLoading = false;
    }
  }

  void clearCache() {
    _regions = null;
  }
}

Future<Map<String, dynamic>?> showFilterBottomSheet(
  BuildContext context, {
  Set<String>? selectedDistricts,
  Set<int>? selectedRatings,
  Set<int>? selectedPriceRanges,
  Set<String>? selectedCategories,
  bool isFromSearchPage = false,
  bool showRating = true,
  bool showPrice = true,
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
        showRating: showRating,
        showPrice: showPrice,
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
    this.showRating = true,
    this.showPrice = true,
  });

  final Set<String> selectedDistricts;
  final Set<int> selectedRatings;
  final Set<int> selectedPriceRanges;
  final Set<String> selectedCategories;
  final bool isFromSearchPage;
  final bool showRating;
  final bool showPrice;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  int selectedFilterIndex = 0;
  Set<int> selectedRatings = {};
  Set<int> selectedPriceRanges = {};
  Set<String> selectedDistricts = {};
  Set<String> selectedCategories = {};

  List<Region> regions = [];
  Region? selectedRegion;
  City? selectedCity;

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
      final cachedRegions = await _locationsCache.getRegions();
      if (mounted) {
        setState(() {
          regions = cachedRegions;
          _restoreSelection();
        });
      }
    } catch (e) {
      debugPrint('Failed to load locations: $e');
      if (mounted) {
        setState(() {
          regions = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (AppLocalizations.of(context)?.failedLoadLocations ?? 'Failed to load locations. Location filters may not be available.'),
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

  void _restoreSelection() {
    if (selectedDistricts.isEmpty || regions.isEmpty) return;

    // Find the region and city for the first selected district
    // This assumes we want to show the context of the selected district
    // If multiple districts from different cities are selected, we pick the first one found

    for (var region in regions) {
      for (var city in region.cities) {
        for (var district in city.districts) {
          if (selectedDistricts.contains(district.districtId)) {
            selectedRegion = region;
            selectedCity = city;
            return;
          }
        }
      }
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
              (AppLocalizations.of(context)?.failedLoadCategories ?? 'Failed to load categories. Some filters may not be available.'),
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
                  style: DMSansFont.textStyle(
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
                          if (widget.showRating)
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
                          if (widget.showPrice)
                            _buildFilterCategoryTile(
                              icon: Icons.payments_outlined,
                              title:
                                  AppLocalizations.of(context)?.price ??
                                  'Price',
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
                                style: DMSansFont.textStyle(
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
                                style: DMSansFont.textStyle(
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
                  style: DMSansFont.textStyle(
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
        final currentLanguage =
            AppLocalizations.of(context)?.localeName ?? 'en';
        final isArabic = currentLanguage == 'ar' || currentLanguage == 'ur';

        return Container(
          padding: const EdgeInsets.only(left: 10, right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                Expanded(
                  child: Center(child: Loader(color: AppColors.primary)),
                )
              else ...[
                const SizedBox(height: 16),
                SearchableDropdown<Region>(
                  hintText: AppLocalizations.of(
                    context,
                  )!.typeProvinceNameToSearch,
                  label: AppLocalizations.of(context)?.province ?? 'Region',
                  value: selectedRegion,
                  items: regions,
                  itemLabel: (region) => region.getName(isArabic),
                  onChanged: (region) {
                    setState(() {
                      selectedRegion = region;
                      selectedCity = null;
                      // We might want to clear selected districts if region changes?
                      // For now, let's keep them but maybe they won't be visible
                      // actually, if we change region, the previously selected districts
                      // (if they belong to the old region) should probably be unchecked
                      // or just kept as "hidden selections".
                      // Let's keep them for now to avoid data loss if user switches back.
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedRegion != null)
                  SearchableDropdown<City>(
                    hintText: AppLocalizations.of(
                      context,
                    )!.typeCityNameToSearch,

                    label: AppLocalizations.of(context)?.city ?? 'City',
                    value: selectedCity,
                    items: selectedRegion!.cities,
                    itemLabel: (city) => city.getName(isArabic),
                    onChanged: (city) {
                      setState(() {
                        selectedCity = city;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                if (selectedCity != null) ...[
                  Text(
                    AppLocalizations.of(context)?.neighbourhood ?? 'District',
                    style: DMSansFont.textStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: 100 + safePadding.bottom,
                      ),
                      itemCount: selectedCity!.districts.length,
                      itemBuilder: (context, index) {
                        final district = selectedCity!.districts[index];
                        final displayName = district.getName(isArabic);
                        final isSelected = selectedDistricts.contains(
                          district.districtId,
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
                                selectedDistricts.add(district.districtId);
                              } else {
                                selectedDistricts.remove(district.districtId);
                              }
                            });
                          },
                          title: Text(
                            displayName,
                            style: DMSansFont.textStyle(
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
                ] else
                  Expanded(
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)?.pleaseSelectCity ??
                            'Please select a city to see districts',
                        style: DMSansFont.textStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
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
                      style: DMSansFont.textStyle(
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
                Expanded(
                  child: Center(child: Loader(color: AppColors.primary)),
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
                      final displayName = category.nameLocalized(
                            languageCode: currentLanguage,
                          ) ??
                          category.name ??
                          '';
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
                          style: DMSansFont.textStyle(
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
                style: DMSansFont.textStyle(
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
