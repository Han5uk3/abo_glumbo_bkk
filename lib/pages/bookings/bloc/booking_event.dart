part of 'booking_bloc.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object> get props => [];
}

class LoadBookingsEvent extends BookingEvent {
  final String customerId;
  const LoadBookingsEvent(this.customerId);
  @override
  List<Object> get props => [customerId];
}

class ChangeStatusEvent extends BookingEvent {
  final BookingStatusType status;
  const ChangeStatusEvent(this.status);
  @override
  List<Object> get props => [status];
}

class RefreshBookingsEvent extends BookingEvent {
  final String customerId;
  const RefreshBookingsEvent(this.customerId);
  @override
  List<Object> get props => [customerId];
}

class CancelBookingEvent extends BookingEvent {
  final BookingModel booking;
  final String reason;
  const CancelBookingEvent(this.booking, this.reason);

  @override
  List<Object> get props => [booking, reason];
}
