import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
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
    on<ToggleFavoriteService>(_toggleFavoriteService);
  }
  static Locale getSavedLocale() {
    String languageCode = LocalStoreHelper.getUserlanguage();
    return Locale(languageCode);
  }

  void _onChangeLocale(ChangeLocale event, Emitter<AccountState> emit) async {
    try {
      if (state.locale.languageCode == event.languageCode) {
        return;
      }

      await LocalStoreHelper.putUserlanguage(event.languageCode);
      emit(state.copyWith(locale: Locale(event.languageCode)));
    } catch (e) {
      // Handle error silently or emit error state if needed
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
      await AppServices.updateCustomerProfile(
        customerData: event.customerData,
        previousCustomerData: event.previousCustomerData,
      );

      // Emit updated customer data if current state contains customer data
      if (state is CustomerDataLoaded) {
        // Ensure uid is not null before fetching fresh data
        final uid = event.customerData.uid;
        if (uid != null) {
          // Fetch fresh customer data from the server to ensure we have the latest updates
          final updatedCustomerData = await AppServices.fetchCustomerData(
            uid: uid,
          );
          emit(
            CustomerDataLoaded(
              customerData: updatedCustomerData,
              locale: state.locale,
            ),
          );
        } else {
          // If uid is null, just emit the event customer data
          emit(
            CustomerDataLoaded(
              customerData: event.customerData,
              locale: state.locale,
            ),
          );
        }
      } else {
        emit(UpdateCustomerProfileSucess(locale: state.locale));
      }
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

  void _toggleFavoriteService(
    ToggleFavoriteService event,
    Emitter<AccountState> emit,
  ) async {
    final currentState = state;

    if (currentState is! CustomerDataLoaded) {
      return;
    }

    // Guard against null service ID
    if (event.service.id == null) {
      emit(
        FavoriteServiceError(
          error: 'Service ID cannot be null',
          locale: currentState.locale,
        ),
      );
      return;
    }

    emit(
      FavoriteServiceUpdating(
        serviceId: event.service.id!,
        locale: currentState.locale,
      ),
    );

    try {
      final customerData = currentState.customerData;
      final isFavorite = customerData.favourites.contains(event.service.id);

      // Create a copy of the favorites list to avoid modifying the original
      final updatedFavorites = List<String>.from(customerData.favourites);

      if (isFavorite) {
        updatedFavorites.remove(event.service.id!);
      } else {
        updatedFavorites.add(event.service.id!);
      }

      // Update Firestore
      await AppFirestore.customersCollectionRef.doc(customerData.uid).update({
        'favourites': updatedFavorites,
      });

      // Create updated customer data
      final updatedCustomerData = CustomerModel(
        role: "customer",
        uid: customerData.uid,
        name: customerData.name,
        email: customerData.email,
        phone: customerData.phone,
        country: customerData.country,
        fcmToken: customerData.fcmToken,
        lanCode: customerData.lanCode,
        addresses: customerData.addresses,
        favourites: updatedFavorites,
        createdAt: customerData.createdAt,
        updatedAt: customerData.updatedAt,
        isAdmin: customerData.isAdmin,
      );

      // Emit the updated state with new customer data
      emit(
        CustomerDataLoaded(
          customerData: updatedCustomerData,
          locale: currentState.locale,
        ),
      );
    } catch (e) {
      emit(
        FavoriteServiceError(error: e.toString(), locale: currentState.locale),
      );
    }
  }
}
