import 'dart:developer';

import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';

abstract class AddressRepository {
  Future<void> clearSelection();
  Future<List<AddressModel>> loadAll();
  Future<void> markSelected(String addressId);
  Future<void> save(AddressModel address);
  Future<void> update(AddressModel address);
  Future<void> remove(AddressModel address);
}

class AppServicesAddressRepository implements AddressRepository {
  @override
  Future<void> clearSelection() async {
    await AppServices.getSelectedAddressAndUpdateIsSelectedToFalse();
  }

  @override
  Future<List<AddressModel>> loadAll() async {
    final uid = LocalStoreHelper.getUID();
    if (uid == null) return [];
    final address = await AppServices.getCustomerAddress();
    log('Loaded addresses: ${address.length}');
    return address;
  }

  @override
  Future<void> markSelected(String addressId) async {
    await AppServices.selectLocation(addressId);
  }

  @override
  Future<void> save(AddressModel address) async {
    await clearSelection();
    final success = await AppServices.addCustomerAddress(address);
    if (!success) throw Exception('Failed to add address');
  }

  @override
  Future<void> update(AddressModel address) async {
    // if updating is semantically remove+save
    await AppServices.removeAddress(address.id);
    await save(address);
  }
@override
  Future<void> remove(AddressModel address) async {
    await AppServices.removeAddress(address.id);
  }
}
