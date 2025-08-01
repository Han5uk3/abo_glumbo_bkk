part of 'address_bloc.dart';

sealed class AddressState extends Equatable {
  const AddressState();

  @override
  List<Object> get props => [];
}

final class AddressInitial extends AddressState {}

class AddressLoading extends AddressState {}

class AddressLoaded extends AddressState {
  final List<AddressModel> addresses;
  const AddressLoaded(this.addresses);
  AddressModel? get selected {
    try {
      return addresses.firstWhere((a) => a.isSelected == true);
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object> get props => [addresses];
}

class AddressError extends AddressState {
  final String message;
  const AddressError(this.message);
  @override
  List<Object> get props => [message];
}
