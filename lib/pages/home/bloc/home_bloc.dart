import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<FetchActiveBookings>(_fetchActiveBookings);
  }

  void _fetchActiveBookings(
    FetchActiveBookings event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(FetchActiveBookingLoading());
      await emit.forEach<List<BookingModel>>(
        AppServices.listenToActiveBookings(),
        onData: (activeBookings) => FetchActiveBookingSuccess(activeBookings),
        onError: (error, stackTrace) => FetchActiveBookingError(error.toString()),
      );
    } catch (e) {
      emit(FetchActiveBookingError(e.toString()));
    }
  }
}
