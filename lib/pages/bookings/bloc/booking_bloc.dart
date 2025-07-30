import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'booking_event.dart';
part 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc() : super(BookingInitial()) {
    on<LoadBookingsEvent>(_onLoadBookings);
    on<ChangeStatusEvent>(_onChangeStatus);
    on<RefreshBookingsEvent>(_onRefreshBookings);
  }

  void _onLoadBookings(
    LoadBookingsEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingsLoading());
    try {
      await emit.forEach<List<BookingModel>>(
        AppServices.listenToBookings(event.customerId),
        onData: (bookings) {
          BookingStatusType initialStatus = BookingStatusType.pending;

          final pendingBookings = bookings
              .where((e) => e.bookingStatusCode == 'P')
              .toList();
          final confirmedBookings = bookings
              .where((e) => e.bookingStatusCode == 'A')
              .toList();
          if (pendingBookings.isEmpty && confirmedBookings.isNotEmpty) {
            initialStatus = BookingStatusType.confirmed;
          }

          return BookingsLoaded(
            allBookings: bookings,
            selectedStatus: state is BookingsLoaded
                ? (state as BookingsLoaded).selectedStatus
                : initialStatus,
          );
        },
        onError: (error, stackTrace) {
          return BookingsError(
            message: 'Failed to load bookings',
            selectedStatus: state is BookingsLoaded
                ? (state as BookingsLoaded).selectedStatus
                : BookingStatusType.pending,
          );
        },
      );
    } catch (e) {
      emit(
        BookingsError(
          message: 'Failed to load bookings',
          selectedStatus: BookingStatusType.pending,
        ),
      );
    }
  }

  void _onChangeStatus(ChangeStatusEvent event, Emitter<BookingState> emit) {
    if (state is BookingsLoaded) {
      final currentState = state as BookingsLoaded;
      emit(currentState.copyWith(selectedStatus: event.status));
    }
  }

  void _onRefreshBookings(
    RefreshBookingsEvent event,
    Emitter<BookingState> emit,
  ) {
    add(LoadBookingsEvent(event.customerId));
  }
}
