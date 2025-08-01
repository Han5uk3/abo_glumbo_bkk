import 'package:abo_glumbo_bbk/models/address.dart';

class AddressSheetResult {
  final AddressModel? selectedAddress;
  final List<AddressModel> updatedAddresses;
  final bool needsAddressSelection;

  AddressSheetResult({
    required this.selectedAddress,
    required this.updatedAddresses,
    this.needsAddressSelection = false,
  });
}
