part of 'account_bloc.dart';

class AccountState extends Equatable {
  final Locale locale;

  const AccountState({this.locale = const Locale('en')});

  AccountState copyWith({Locale? locale}) {
    return AccountState(locale: locale ?? this.locale);
  }

  @override
  List<Object?> get props => [locale];
}

final class AccountInitial extends AccountState {}
