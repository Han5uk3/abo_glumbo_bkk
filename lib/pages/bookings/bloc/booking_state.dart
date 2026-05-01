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
        final pending = allBookings
            .where((e) => e.bookingStatusCode == 'P')
            .toList();
        // Sort by createdAt in descending order (newest first)
        pending.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        return pending;
      case BookingStatusType.confirmed:
        final confirmed = allBookings
            .where((e) => e.bookingStatusCode == 'A')
            .toList();
        // Sort by acceptedAt in descending order (newest first)
        confirmed.sort((a, b) {
          if (a.acceptedAt == null && b.acceptedAt == null) return 0;
          if (a.acceptedAt == null) return 1;
          if (b.acceptedAt == null) return -1;
          return b.acceptedAt!.compareTo(a.acceptedAt!);
        });
        return confirmed;
      case BookingStatusType.completed:
        final completed = allBookings.where((e) {
          final isCompleted = e.bookingStatusCode == 'C' && e.paymentCompleted;

          return isCompleted;
        }).toList();
        // Sort by paymentCompletedAt in descending order (newest first)
        completed.sort((a, b) {
          if (a.paymentCompletedAt == null && b.paymentCompletedAt == null) {
            return 0;
          }
          if (a.paymentCompletedAt == null) {
            return 1;
          }
          if (b.paymentCompletedAt == null) {
            return -1;
          }
          return b.paymentCompletedAt!.compareTo(a.paymentCompletedAt!);
        });
        return completed;
      case BookingStatusType.pendingPayment:
        final pending = allBookings.where((e) {
          final isPending = e.bookingStatusCode == 'CP';
          final isVerification = e.bookingStatusCode == 'VP'; 

          return isPending || isVerification;
        }).toList();
        // Sort by completedAt in descending order (newest first)
        pending.sort((a, b) {
          if (a.completedAt == null && b.completedAt == null) return 0;
          if (a.completedAt == null) return 1;
          if (b.completedAt == null) return -1;
          return b.completedAt!.compareTo(a.completedAt!);
        });
        return pending;
      case BookingStatusType.cancelled:
        return allBookings
            .where(
              (e) => e.bookingStatusCode == 'R' || e.bookingStatusCode == 'XC',
            )
            .toList();
      case BookingStatusType.onWarranty:
        return allBookings.where((e) {
          final completed = e.bookingStatusCode == 'C' && e.paymentCompleted;
          final warranty = e.warranty != null;
          return completed && warranty;
        }).toList();
      case BookingStatusType.verificationPending:
        return allBookings.where((e) => e.bookingStatusCode == 'VP').toList();
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
