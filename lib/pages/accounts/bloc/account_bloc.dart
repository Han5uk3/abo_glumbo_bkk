import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'account_event.dart';
part 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc() : super(AccountState(locale: getSavedLocale())) {
    on<ChangeLocale>(_onChangeLocale);
  }
  static Locale getSavedLocale() {
    String languageCode = LocalStoreHelper.getUserlanguage();
    return Locale(languageCode);
  }

  void _onChangeLocale(ChangeLocale event, Emitter<AccountState> emit) async {
    await LocalStoreHelper.putUserlanguage(event.languageCode);
    emit(state.copyWith(locale: Locale(event.languageCode)));
  }
}
