part of 'account_bloc.dart';

@immutable
sealed class AccountEvent {}

class ChangeLocale extends AccountEvent {
  final String languageCode;
  ChangeLocale({required this.languageCode});
  List<Object> get props => [languageCode];
}

class ListenCustomerData extends AccountEvent {
  final String uid;
  ListenCustomerData({required this.uid});
  List<Object> get props => [uid];
}

class UpdateCustomerProfile extends AccountEvent {
  final CustomerModel customerData;
  UpdateCustomerProfile({required this.customerData});
  List<Object> get props => [customerData];
}

class UpdateCustomerLocation extends AccountEvent {}
