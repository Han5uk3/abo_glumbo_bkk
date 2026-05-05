import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class NewBookingBloc extends Bloc<BookingEvent, BookingState> {
  NewBookingBloc() : super(BookingInitial()) {
    on<CreateBookingEvent>(_onCreateBooking);
  }

  Future<void> _onCreateBooking(
    CreateBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());

    try {
      // Call your booking service
      final bookingId = await BookingUtils.saveBooking(
        service: event.service,
        selectedDate: event.selectedDate,
        paymentMode: "Outside App", // Default to no upfront payment
        customerData: event.customerData,
        notes: event.notes,
        selectedImage: event.selectedImage,
        selectedVideo: event.selectedVideo,
        timeSlot: event.timeSlot,
        agent: event.agent,
        selectedAddress: event.selectedAddress,
        serviceLocation: event.serviceLocation,
      );

      // Emit success with booking ID if needed
      if (bookingId != null) {
        emit(BookingSuccess(bookingId: bookingId));
      } else {
        emit(BookingError(message: "Failed to create booking"));
      }
    } catch (e) {
      emit(BookingError(message: e.toString()));
    }
  }
}
