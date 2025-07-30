import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:equatable/equatable.dart';

class FilterCriteria extends Equatable {
  final Set<String> selectedDistricts;
  final Set<int> selectedRatings;
  final Set<int> selectedPriceRanges;
  final Set<String> selectedCategories;

  const FilterCriteria({
    this.selectedDistricts = const {},
    this.selectedRatings = const {},
    this.selectedPriceRanges = const {},
    this.selectedCategories = const {},
  });

  bool get hasActiveFilters =>
      selectedDistricts.isNotEmpty ||
      selectedRatings.isNotEmpty ||
      selectedPriceRanges.isNotEmpty ||
      selectedCategories.isNotEmpty;

  bool matchesService(ServiceModel service) {
    // District filter
    if (selectedDistricts.isNotEmpty) {
      final matchesDistrict = service.locations?.any(
        (location) => selectedDistricts.contains(location),
      );
      if (!(matchesDistrict ?? false)) return false;
    }

    // Rating filter
    if (selectedRatings.isNotEmpty) {
      final avgRating = service.averageRating;
      final matchesRating = selectedRatings.contains(avgRating.round());
      if (!matchesRating) return false;
    }

    // Price range filter
    if (selectedPriceRanges.isNotEmpty) {
      final matchesPrice = selectedPriceRanges.any(
        (range) => _isInPriceRange(range, service.price ?? 0.0),
      );
      if (!matchesPrice) return false;
    }

    // Category filter
    if (selectedCategories.isNotEmpty) {
      final matchesCategory = selectedCategories.contains(service.category);
      if (!matchesCategory) return false;
    }

    return true;
  }

  bool _isInPriceRange(int index, double price) {
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

  FilterCriteria copyWith({
    Set<String>? selectedDistricts,
    Set<int>? selectedRatings,
    Set<int>? selectedPriceRanges,
    Set<String>? selectedCategories,
  }) {
    return FilterCriteria(
      selectedDistricts: selectedDistricts ?? this.selectedDistricts,
      selectedRatings: selectedRatings ?? this.selectedRatings,
      selectedPriceRanges: selectedPriceRanges ?? this.selectedPriceRanges,
      selectedCategories: selectedCategories ?? this.selectedCategories,
    );
  }

  @override
  List<Object> get props => [
    selectedDistricts,
    selectedRatings,
    selectedPriceRanges,
    selectedCategories,
  ];
}
