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
  final CustomerModel previousCustomerData;
  UpdateCustomerProfile({
    required this.customerData,
    required this.previousCustomerData,
  });
  List<Object> get props => [customerData, previousCustomerData];
}

class UpdateCustomerLocation extends AccountEvent {}

class ToggleFavoriteService extends AccountEvent {
  final ServiceModel service;
  ToggleFavoriteService({required this.service});

  List<Object> get props => [service];
}
