part of 'account_bloc.dart';

@immutable
sealed class AccountEvent {}

class ChangeLocale extends AccountEvent {
  final String languageCode;
  ChangeLocale({required this.languageCode});
  List<Object> get props => [languageCode];
}
