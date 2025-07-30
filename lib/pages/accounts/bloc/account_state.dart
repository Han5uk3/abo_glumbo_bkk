part of 'account_bloc.dart';

class AccountState extends Equatable {
  final Locale locale;

  // Remove the default English locale to prevent it from being used accidentally
  const AccountState({required this.locale});

  AccountState copyWith({Locale? locale}) {
    return AccountState(locale: locale ?? this.locale);
  }

  @override
  List<Object?> get props => [locale];
}

class CustomerDataLoading extends AccountState {
  const CustomerDataLoading({required super.locale});
}

class CustomerDataLoaded extends AccountState {
  final CustomerModel customerData;

  const CustomerDataLoaded({required this.customerData, required super.locale});

  @override
  List<Object?> get props => [customerData, locale];
}

class CustomerDataError extends AccountState {
  final String error;

  const CustomerDataError({required this.error, required super.locale});

  @override
  List<Object?> get props => [error, locale];
}

class UpdateCustomerProfileLoading extends AccountState {
  const UpdateCustomerProfileLoading({required super.locale});
  @override
  List<Object?> get props => [locale];
}

class UpdateCustomerProfileSucess extends AccountState {
  const UpdateCustomerProfileSucess({required super.locale});
  @override
  List<Object?> get props => [locale];
}

class UpdateCustomerProfileError extends AccountState {
  final String error;

  const UpdateCustomerProfileError({
    required this.error,
    required super.locale,
  });

  @override
  List<Object?> get props => [error, locale];
}

class UpdateCustomerLocationLoading extends AccountState {
  const UpdateCustomerLocationLoading({required super.locale});
  @override
  List<Object?> get props => [locale];
}

class UpdateCustomerLocationSuccess extends AccountState {
  final String locationName;

  const UpdateCustomerLocationSuccess({
    required this.locationName,
    required super.locale,
  });
  @override
  List<Object?> get props => [locationName, locale];
}

class UpdateCustomerLocationError extends AccountState {
  final String error;

  const UpdateCustomerLocationError({
    required this.error,
    required super.locale,
  });

  @override
  List<Object?> get props => [error, locale];
}

class FavoriteServiceUpdating extends AccountState {
  final String serviceId;
  const FavoriteServiceUpdating({
    required this.serviceId,
    required super.locale,
  });

  @override
  List<Object?> get props => [serviceId, locale];
}

class FavoriteServiceUpdated extends AccountState {
  final String serviceId;
  const FavoriteServiceUpdated({
    required this.serviceId,
    required super.locale,
  });

  @override
  List<Object?> get props => [serviceId, locale];
}

class FavoriteServiceError extends AccountState {
  final String error;
  const FavoriteServiceError({required this.error, required super.locale});

  @override
  List<Object?> get props => [error, locale];
}

class UpdateCustomerPhoneNumberLoading extends AccountState {
  const UpdateCustomerPhoneNumberLoading({required super.locale});

  @override
  List<Object?> get props => [locale];
}

class UpdateCustomerPhoneNumberSuccess extends AccountState {
  const UpdateCustomerPhoneNumberSuccess({required super.locale});

  @override
  List<Object?> get props => [locale];
}

class UpdateCustomerPhoneNumberError extends AccountState {
  final String error;

  const UpdateCustomerPhoneNumberError({
    required this.error,
    required super.locale,
  });

  @override
  List<Object?> get props => [error, locale];
}
