part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchInitialized extends SearchEvent {
  final String? initialQuery;
  const SearchInitialized({this.initialQuery});

  @override
  List<Object?> get props => [initialQuery];
}

class LoadServices extends SearchEvent {}

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
  final CustomerModel customerData;
  const FavoriteToggled({required this.serviceId, required this.customerData});

  @override
  List<Object> get props => [serviceId, customerData];
}
