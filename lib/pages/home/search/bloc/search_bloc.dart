import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/home/search/model/filter_criteria.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  List<ServiceModel> _allServices = [];
  String? _currentQuery;
  FilterCriteria _currentFilters = const FilterCriteria();

  SearchBloc() : super(SearchInitial()) {
    on<SearchInitialized>(_onSearchInitialized);
    on<LoadServices>(_onLoadServices);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<FiltersApplied>(_onFiltersApplied);
    on<FiltersCleared>(_onFiltersCleared);
    on<FavoriteToggled>(_onFavoriteToggled);
  }

  Future<void> _onSearchInitialized(
    SearchInitialized event,
    Emitter<SearchState> emit,
  ) async {
    emit(SearchLoading());
    _currentQuery = event.initialQuery;
    add(LoadServices());
  }

  Future<void> _onLoadServices(
    LoadServices event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final querySnapshot = await AppFirestore.servicesCollectionRef
          .where('isActive', isEqualTo: true)
          .get();

      _allServices = querySnapshot.docs.map((doc) {
        return ServiceModel.fromQueryDocumentSnapshot(doc);
      }).toList();

      _applyFiltersAndSearch(emit);
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    _currentQuery = event.query.isEmpty ? null : event.query;
    _applyFiltersAndSearch(emit);
  }

  Future<void> _onFiltersApplied(
    FiltersApplied event,
    Emitter<SearchState> emit,
  ) async {
    _currentFilters = event.filters;
    _applyFiltersAndSearch(emit);
  }

  Future<void> _onFiltersCleared(
    FiltersCleared event,
    Emitter<SearchState> emit,
  ) async {
    _currentFilters = const FilterCriteria();
    _currentQuery = null;
    _applyFiltersAndSearch(emit);
  }

  Future<void> _onFavoriteToggled(
    FavoriteToggled event,
    Emitter<SearchState> emit,
  ) async {
    try {
      List<String> updatedFavorites = List.from(event.customerData.favourites);
      final isFavorite = updatedFavorites.contains(event.serviceId);

      if (isFavorite) {
        updatedFavorites.remove(event.serviceId);
      } else {
        updatedFavorites.add(event.serviceId);
      }

      await AppFirestore.customersCollectionRef
          .doc(event.customerData.uid)
          .update({'favourites': updatedFavorites});

      emit(
        FavoriteUpdateSuccess(
          serviceId: event.serviceId,
          isFavorite: !isFavorite,
        ),
      );
    } catch (e) {
      emit(FavoriteUpdateError(e.toString()));
    }
  }

  void _applyFiltersAndSearch(Emitter<SearchState> emit) {
    final filteredServices = _filterServices(_allServices);
    emit(
      SearchSuccess(
        services: filteredServices,
        query: _currentQuery,
        filters: _currentFilters,
        hasActiveFilters:
            _currentFilters.hasActiveFilters ||
            (_currentQuery?.isNotEmpty ?? false),
      ),
    );
  }

  List<ServiceModel> _filterServices(List<ServiceModel> services) {
    var filtered = services;

    // Apply search query filter
    if (_currentQuery != null && _currentQuery!.isNotEmpty) {
      filtered = filtered.where((service) {
        final query = _currentQuery!.toLowerCase();
        final serviceName = service.name?.toLowerCase() ?? '';
        final serviceNameAr = service.name_ar?.toLowerCase() ?? '';
        final serviceNameUr = service.name_ur?.toLowerCase() ?? '';
        final serviceDescription = service.description?.toLowerCase() ?? '';
        final serviceDescriptionAr =
            service.description_ar?.toLowerCase() ?? '';
        final serviceDescriptionUr =
            service.description_ur?.toLowerCase() ?? '';

        return serviceName.contains(query) ||
            serviceNameAr.contains(query) ||
            serviceNameUr.contains(query) ||
            serviceDescription.contains(query) ||
            serviceDescriptionAr.contains(query) ||
            serviceDescriptionUr.contains(query);
      }).toList();
    }

    // Apply other filters
    if (_currentFilters.hasActiveFilters) {
      filtered = filtered.where((service) {
        return _currentFilters.matchesService(service);
      }).toList();
    }

    return filtered;
  }
}
