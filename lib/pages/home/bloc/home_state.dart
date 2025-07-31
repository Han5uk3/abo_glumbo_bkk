part of 'home_bloc.dart';

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

final class HomeInitial extends HomeState {}

final class FetchActiveBookingLoading extends HomeState {}

final class FetchActiveBookingSuccess extends HomeState {
  final List<BookingModel> activeBookings;

  const FetchActiveBookingSuccess(this.activeBookings);

  @override
  List<Object> get props => [activeBookings];
}

final class FetchActiveBookingError extends HomeState {
  final String error;

  const FetchActiveBookingError(this.error);

  @override
  List<Object> get props => [error];
}
