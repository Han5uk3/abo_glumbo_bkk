part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchInitialized extends SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object> get props => [query];
}

class FiltersApplied extends SearchEvent {
  final FilterCriteria filters;
  const FiltersApplied(this.filters);

  @override
  List<Object> get props => [filters];
}

class FiltersCleared extends SearchEvent {}

class FavoriteToggled extends SearchEvent {
  final String serviceId;
  const FavoriteToggled(this.serviceId);

  @override
  List<Object> get props => [serviceId];
}
