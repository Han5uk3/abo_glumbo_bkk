import 'dart:developer';

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
    on<CancelBookingEvent>(_onCancelBooking);
  }

  void _onLoadBookings(
    LoadBookingsEvent event,
    Emitter<BookingState> emit,
  ) async {
    BookingStatusType statusToUse = event.selectedStatus;

    if (!event.isInitialLoad && state is BookingsLoaded) {
      statusToUse = (state as BookingsLoaded).selectedStatus;
    }

    emit(BookingsLoading(selectedStatus: statusToUse));

    try {
      await emit.forEach<List<BookingModel>>(
        AppServices.listenToBookings(event.customerId),
        onData: (allBookings) {
          return BookingsLoaded(
            allBookings: allBookings,
            selectedStatus: statusToUse,
          );
        },
        onError: (error, stackTrace) {
          log(stackTrace.toString());
          return BookingsError(
            message: error.toString(),
            selectedStatus: statusToUse,
          );
        },
      );
    } catch (e) {
      emit(BookingsError(message: e.toString(), selectedStatus: statusToUse));
    }
  }

  void _onChangeStatus(ChangeStatusEvent event, Emitter<BookingState> emit) {
    if (state is BookingsLoaded) {
      final currentState = state as BookingsLoaded;
      emit(currentState.copyWith(selectedStatus: event.status));
    }
  }

  // void _onChangeStatus(ChangeStatusEvent event, Emitter<BookingState> emit) {
  //   if (state is BookingsLoaded) {
  //     final currentState = state as BookingsLoaded;
  //     emit(currentState.copyWith(selectedStatus: event.status));
  //   }
  // }

  void _onRefreshBookings(
    RefreshBookingsEvent event,
    Emitter<BookingState> emit,
  ) {
    add(LoadBookingsEvent(event.customerId, isInitialLoad: false));
  }

  void _onCancelBooking(
    CancelBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(CancelBookingLoading());
    await AppServices.cancelBooking(event.booking, event.reason)
        .then((success) {
          if (success) {
            emit(CancelBookingSuccess());
          } else {
            emit(CancelBookingError(message: 'Failed to cancel booking'));
          }
        })
        .catchError((error) {
          emit(CancelBookingError(message: error.toString()));
        });
  }
}
