part of 'address_bloc.dart';

sealed class AddressEvent extends Equatable {
  const AddressEvent();

  @override
  List<Object> get props => [];
}

class LoadAddresses extends AddressEvent {}

class SelectAddress extends AddressEvent {
  final AddressModel address;
  const SelectAddress(this.address);
  @override
  List<Object> get props => [address];
}

class AddOrUpdateAddress extends AddressEvent {
  final AddressModel address;
  const AddOrUpdateAddress(this.address);
  @override
  List<Object> get props => [address];
}

class RemoveAddress extends AddressEvent {
  final AddressModel address;
  const RemoveAddress(this.address);
  @override
  List<Object> get props => [address];
}
