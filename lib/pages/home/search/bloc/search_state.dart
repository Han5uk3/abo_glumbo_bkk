part of 'search_bloc.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final List<ServiceModel> services;
  final String? query;
  final FilterCriteria filters;
  final bool hasActiveFilters;

  const SearchSuccess({
    required this.services,
    this.query,
    required this.filters,
    required this.hasActiveFilters,
  });

  @override
  List<Object?> get props => [services, query, filters, hasActiveFilters];

  SearchSuccess copyWith({
    List<ServiceModel>? services,
    String? query,
    FilterCriteria? filters,
    bool? hasActiveFilters,
  }) {
    return SearchSuccess(
      services: services ?? this.services,
      query: query ?? this.query,
      filters: filters ?? this.filters,
      hasActiveFilters: hasActiveFilters ?? this.hasActiveFilters,
    );
  }
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);

  @override
  List<Object> get props => [message];
}

class FavoriteUpdateSuccess extends SearchState {
  final String serviceId;
  final bool isFavorite;

  const FavoriteUpdateSuccess({
    required this.serviceId,
    required this.isFavorite,
  });

  @override
  List<Object> get props => [serviceId, isFavorite];
}

class FavoriteUpdateError extends SearchState {
  final String message;
  const FavoriteUpdateError(this.message);

  @override
  List<Object> get props => [message];
}
