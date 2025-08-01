import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/services/address_services.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'address_event.dart';
part 'address_state.dart';

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  final AppServicesAddressRepository repository;
  AddressBloc(this.repository) : super(AddressInitial()) {
    on<LoadAddresses>(_loadAddresses);
    on<SelectAddress>(_selectAddress);
    on<AddOrUpdateAddress>(_addOrUpdateAddress);
    on<RemoveAddress>(_removeAddress);
  }
  Future<void> _loadAddresses(
    LoadAddresses event,
    Emitter<AddressState> emit,
  ) async {
    emit(AddressLoading());
    try {
      final list = await repository.loadAll();
      emit(AddressLoaded(list));
    } catch (ex) {
      emit(AddressError(ex.toString()));
    }
  }

  Future<void> _selectAddress(
    SelectAddress event,
    Emitter<AddressState> emit,
  ) async {
    if (state is! AddressLoaded) return;
    final current = (state as AddressLoaded).addresses;
    emit(AddressLoading());
    try {
      await repository.clearSelection();
      await repository.markSelected(event.address.id);
      final updated = current
          .map(
            (a) => a.id == event.address.id
                ? a.copyWith(isSelected: true)
                : a.copyWith(isSelected: false),
          )
          .toList();
      emit(AddressLoaded(updated));
    } catch (ex) {
      emit(AddressError(ex.toString()));
    }
  }

  Future<void> _addOrUpdateAddress(
    AddOrUpdateAddress event,
    Emitter<AddressState> emit,
  ) async {
    if (state is! AddressLoaded) return;
    final current = (state as AddressLoaded).addresses;
    emit(AddressLoading());
    try {
      await repository.clearSelection();
      final newAddress = event.address.copyWith(isSelected: true);
      final exists = current.indexWhere((a) => a.id == newAddress.id);
      if (exists >= 0) {
        await repository.update(newAddress);
      } else {
        await repository.save(newAddress);
      }
      await repository.markSelected(newAddress.id);
      final updated =
          current
              .map((a) => a.copyWith(isSelected: false))
              .where((a) => a.id != newAddress.id)
              .toList()
            ..add(newAddress);
      emit(AddressLoaded(updated));
    } catch (ex) {
      emit(AddressError(ex.toString()));
    }
  }

  Future<void> _removeAddress(
    RemoveAddress event,
    Emitter<AddressState> emit,
  ) async {
    if (state is! AddressLoaded) return;
    final current = (state as AddressLoaded).addresses;
    emit(AddressLoading());
    try {
      await repository.remove(event.address);
      final updated = current.where((a) => a.id != event.address.id).toList();
      if (event.address.isSelected ?? false) {
        await repository.clearSelection();
      }
      emit(AddressLoaded(updated));
    } catch (ex) {
      emit(AddressError(ex.toString()));
    }
  }
}
