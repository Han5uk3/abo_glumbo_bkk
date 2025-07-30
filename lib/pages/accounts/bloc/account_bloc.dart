import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/location_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'account_event.dart';
part 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc() : super(AccountState(locale: getSavedLocale())) {
    on<ChangeLocale>(_onChangeLocale);
    on<ListenCustomerData>(_listenCustomerData);
    on<UpdateCustomerProfile>(_updateCustomerProfile);
    on<UpdateCustomerLocation>(_updateCustomerLocation);
  }
  static Locale getSavedLocale() {
    String languageCode = LocalStoreHelper.getUserlanguage();
    debugPrint('🔍 Getting saved locale: $languageCode');
    return Locale(languageCode);
  }

  void _onChangeLocale(ChangeLocale event, Emitter<AccountState> emit) async {
    try {
      debugPrint(
        '🌐 AccountBloc: Received ChangeLocale event: ${event.languageCode}',
      );
      debugPrint(
        '🌐 AccountBloc: Current state locale: ${state.locale.languageCode}',
      );

      if (state.locale.languageCode == event.languageCode) {
        debugPrint(
          '⚠️ AccountBloc: Locale already set to ${event.languageCode}, skipping...',
        );
        return;
      }

      await LocalStoreHelper.putUserlanguage(event.languageCode);
      debugPrint('✅ Language saved successfully: ${event.languageCode}');
      emit(state.copyWith(locale: Locale(event.languageCode)));
      debugPrint('🎯 AccountBloc: Emitted new locale: ${event.languageCode}');
    } catch (e) {
      debugPrint('❌ Error saving language: $e');
    }
  }

  void _listenCustomerData(
    ListenCustomerData event,
    Emitter<AccountState> emit,
  ) async {
    emit(CustomerDataLoading(locale: state.locale));
    try {
      final customerData = await AppServices.fetchCustomerData(uid: event.uid);
      emit(
        CustomerDataLoaded(customerData: customerData, locale: state.locale),
      );
    } catch (e) {
      emit(CustomerDataError(error: e.toString(), locale: state.locale));
    }
  }

  void _updateCustomerProfile(
    UpdateCustomerProfile event,
    Emitter<AccountState> emit,
  ) async {
    emit(UpdateCustomerProfileLoading(locale: state.locale));
    try {
      await AppServices.updateCustomerProfile(customerData: event.customerData);
      emit(UpdateCustomerProfileSucess(locale: state.locale));
    } catch (e) {
      emit(
        UpdateCustomerProfileError(error: e.toString(), locale: state.locale),
      );
    }
  }

  void _updateCustomerLocation(
    UpdateCustomerLocation event,
    Emitter<AccountState> emit,
  ) async {
    emit(UpdateCustomerLocationLoading(locale: state.locale));
    try {
      await LocationService().fetchLocation();
      final fetchedLocation = LocationService().userLocation;

      String? locationToUpdate;
      if (fetchedLocation != null && fetchedLocation.isNotEmpty) {
        locationToUpdate = fetchedLocation;

        await AppServices.updateCustomerLocation(fetchedLocation);
      }

      emit(
        UpdateCustomerLocationSuccess(
          locale: state.locale,
          locationName: locationToUpdate ?? 'N/A',
        ),
      );
    } catch (e) {
      emit(
        UpdateCustomerLocationError(error: e.toString(), locale: state.locale),
      );
    }
  }
}
