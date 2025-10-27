part of 'booking_bloc.dart';

sealed class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object> get props => [];
}

final class BookingInitial extends BookingState {}

class BookingsLoading extends BookingState {
  final BookingStatusType selectedStatus;
  final List<BookingModel> allBookings;

  const BookingsLoading({
    this.selectedStatus = BookingStatusType.pending,
    this.allBookings = const [],
  });
  @override
  List<Object> get props => [selectedStatus, allBookings];
}

class BookingsLoaded extends BookingState {
  final List<BookingModel> allBookings;
  final BookingStatusType selectedStatus;

  const BookingsLoaded({
    required this.allBookings,
    required this.selectedStatus,
  });

  List<BookingModel> get filteredBookings {
    switch (selectedStatus) {
      case BookingStatusType.pending:
        return allBookings.where((e) => e.bookingStatusCode == 'P').toList();
      case BookingStatusType.confirmed:
        return allBookings.where((e) => e.bookingStatusCode == 'A').toList();
      case BookingStatusType.completed:
        return allBookings
            .where(
              (e) => e.bookingStatusCode == 'C' && e.review?.rating == null,
            )
            .toList();
      case BookingStatusType.pastBookings:
        return allBookings
            .where(
              (e) =>
                  e.bookingStatusCode != 'P' &&
                  e.bookingStatusCode != 'A' &&
                  e.review?.rating != null &&
                  e.paymentCompleted,
            )
            .toList();
    }
  }

  BookingsLoaded copyWith({
    List<BookingModel>? allBookings,
    BookingStatusType? selectedStatus,
  }) {
    return BookingsLoaded(
      allBookings: allBookings ?? this.allBookings,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }

  @override
  List<Object> get props => [allBookings, selectedStatus];
}

class BookingsError extends BookingState {
  final String message;
  final BookingStatusType selectedStatus;

  const BookingsError({
    required this.message,
    this.selectedStatus = BookingStatusType.pending,
  });
  @override
  List<Object> get props => [message, selectedStatus];
}

class CancelBookingLoading extends BookingState {}

class CancelBookingSuccess extends BookingState {}

class CancelBookingError extends BookingState {
  final String message;

  const CancelBookingError({required this.message});

  @override
  List<Object> get props => [message];
}
