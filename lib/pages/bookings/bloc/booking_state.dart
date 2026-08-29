part of 'booking_bloc.dart';

sealed class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object> get props => [];
}

final class BookingInitial extends BookingState {}

/// When the customer finished paying for a booking. `paymentCompletedAt` is
/// the field the payment flow writes today; the fallbacks keep bookings paid
/// before it existed from sinking to the bottom of every list.
DateTime? _paymentCompletionTime(BookingModel booking) =>
    (booking.paymentCompletedAt ?? booking.paidAt ?? booking.completedAt)
        ?.toDate();

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
        // Sort by booked date in descending order (newest first)
        pending.sort((a, b) {
          final aDate = a.createdAt ?? a.bookingDateTime;
          final bDate = b.createdAt ?? b.bookingDateTime;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return pending;

      case BookingStatusType.confirmed:
        final confirmed = allBookings
            .where((e) => e.bookingStatusCode == 'A')
            .toList();
        // Sort by accepted/assigned date in descending order (newest first)
        confirmed.sort((a, b) {
          final aDate = a.assignedAt ?? a.acceptedAt ?? a.createdAt;
          final bDate = b.assignedAt ?? b.acceptedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return confirmed;

      case BookingStatusType.completed:
        final completed = allBookings.where((e) {
          final isCompleted = e.bookingStatusCode == 'C' && e.paymentCompleted;
          return isCompleted;
        }).toList();
        // Sort by completed date in descending order (newest first)
        // Matches the exact date shown on the card: completedAt ?? paymentCompletedAt ?? paidAt ?? updatedAt ?? createdAt
        completed.sort((a, b) {
          final aDate = a.completedAt ?? a.paymentCompletedAt ?? a.paidAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.completedAt ?? b.paymentCompletedAt ?? b.paidAt ?? b.updatedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return completed;

      case BookingStatusType.pendingPayment:
        final pending = allBookings.where((e) {
          final isPending = e.bookingStatusCode == 'CP';
          final isVerification = e.bookingStatusCode == 'VP';
          return isPending || isVerification;
        }).toList();
        // Sort by payment/completion date in descending order (newest first)
        pending.sort((a, b) {
          final aDate = a.paidAt ?? a.completedAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.paidAt ?? b.completedAt ?? b.updatedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return pending;

      case BookingStatusType.cancelled:
        final cancelled = allBookings
            .where(
              (e) => e.bookingStatusCode == 'X' || e.bookingStatusCode == 'XC',
            )
            .toList();
        // Sort by cancelled date in descending order (newest first)
        cancelled.sort((a, b) {
          final aDate = a.cancelledAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.cancelledAt ?? b.updatedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return cancelled;

      case BookingStatusType.rejected:
        final rejected = allBookings
            .where((e) => e.bookingStatusCode == 'R')
            .toList();
        // Sort by rejected date in descending order (newest first)
        rejected.sort((a, b) {
          final aDate = a.rejectedAt ?? a.cancelledAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.rejectedAt ?? b.cancelledAt ?? b.updatedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return rejected;

      case BookingStatusType.onWarranty:
        final onWarranty = allBookings.where((e) {
          final completed = e.bookingStatusCode == 'C' && e.paymentCompleted;
          final warranty = e.warranty != null;
          return completed && warranty;
        }).toList();
        // Claims with a repair request come first, newest request on top -
        // those are the ones the customer is waiting on. The untouched
        // warranties follow, newest payment/completed first.
        onWarranty.sort((a, b) {
          final aRequested = a.warranty?.requestedOn;
          final bRequested = b.warranty?.requestedOn;
          if (aRequested != null && bRequested != null) {
            return bRequested.compareTo(aRequested);
          }
          if (aRequested != null) return -1;
          if (bRequested != null) return 1;

          final aPaid = _paymentCompletionTime(a);
          final bPaid = _paymentCompletionTime(b);
          if (aPaid == null && bPaid == null) return 0;
          if (aPaid == null) return 1;
          if (bPaid == null) return -1;
          return bPaid.compareTo(aPaid);
        });
        return onWarranty;

      case BookingStatusType.verificationPending:
        final vp = allBookings.where((e) => e.bookingStatusCode == 'VP').toList();
        vp.sort((a, b) {
          final aDate = a.paidAt ?? a.completedAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.paidAt ?? b.completedAt ?? b.updatedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return vp;
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
