import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/home/search/model/filter_criteria.dart';
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
    try {
      // final result = await _searchServices.execute();
      // result.fold((failure) => emit(SearchError(failure.message)), (services) {
      //   _allServices = services;
      //   emit(
      //     SearchSuccess(
      //       services: services,
      //       query: _currentQuery,
      //       filters: _currentFilters,
      //       hasActiveFilters: _currentFilters.hasActiveFilters,
      //     ),
      //   );
      // });
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
      // final result = await _toggleFavorite.execute(event.serviceId);
      // result.fold(
      //   (failure) => emit(SearchError(failure.message)),
      //   (isFavorite) => emit(
      //     FavoriteUpdateSuccess(
      //       serviceId: event.serviceId,
      //       isFavorite: isFavorite,
      //     ),
      //   ),
      // );
    } catch (e) {
      emit(SearchError(e.toString()));
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
        return service.name!.toLowerCase().contains(query) ||
            service.description!.toLowerCase().contains(query);
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
