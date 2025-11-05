import 'package:abo_glumbo_bbk/common_widgets/location_map_picker.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/address_result.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/address_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class AddressSaveSheet extends StatefulWidget {
  Function(AddressModel)? onAddressSelected;
  Map<String, dynamic> initialPosition;
  final bool isChangingAddress;

  AddressSaveSheet({
    super.key,
    this.onAddressSelected,
    this.initialPosition = const {'latitude': 0.0, 'longitude': 0.0},
    this.isChangingAddress = false,
  });

  @override
  State<AddressSaveSheet> createState() => _AddressSaveSheetState();
}

class _AddressSaveSheetState extends State<AddressSaveSheet> {
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  List<AddressModel> _currentAddresses = [];
  bool _isLoading = true;
  bool _isAddingNewAddress = false;
  bool _isRemovingAddress = false;

  @override
  void initState() {
    super.initState();
    context.read<AddressBloc>().add(LoadAddresses());
  }

  @override
  void dispose() {
    _streetController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  void _removeAddress(AddressModel address) async {
    if (_isRemovingAddress) return;

    setState(() {
      _isRemovingAddress = true;
    });

    try {
      final bool wasSelected = address.isSelected ?? false;

      setState(() {
        _currentAddresses.removeWhere((addr) => addr.id == address.id);
      });

      context.read<AddressBloc>().add(RemoveAddress(address));

      if (wasSelected) {
        await Future.delayed(const Duration(milliseconds: 200));

        Navigator.of(context).pop(
          AddressSheetResult(
            selectedAddress: null,
            updatedAddresses: _currentAddresses,
            needsAddressSelection: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingAddress = false;
        });
      }
    }
  }

  Widget _buildAddressList(List<AddressModel> addresses) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: Directionality.of(context),
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: Directionality.of(context) == TextDirection.rtl
                          ? 0
                          : 16,
                      right: Directionality.of(context) == TextDirection.rtl
                          ? 16
                          : 0,
                      top: 0,
                      bottom: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context)?.savedAddresses ??
                          'Pick the address where you need the service.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isAddingNewAddress
                        ? null
                        : () async {
                            setState(() {
                              _isAddingNewAddress = true;
                            });

                            try {
                              final newAddress =
                                  await Navigator.push<AddressModel>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LocationMapPicker(
                                      
                                        userLatitude:
                                            widget.initialPosition['lat'],
                                        userLongitude:
                                            widget.initialPosition['lon'],
                                      ),
                                    ),
                                  );

                              if (newAddress != null && mounted) {
                                context.read<AddressBloc>().add(
                                  AddOrUpdateAddress(newAddress),
                                );

                                setState(() {
                                  _currentAddresses =
                                      _currentAddresses
                                          .map(
                                            (addr) => addr.copyWith(
                                              isSelected: false,
                                            ),
                                          )
                                          .toList()
                                        ..add(
                                          newAddress.copyWith(isSelected: true),
                                        );
                                });

                                Navigator.of(context).pop(
                                  AddressSheetResult(
                                    selectedAddress: newAddress.copyWith(
                                      isSelected: true,
                                    ),
                                    updatedAddresses: _currentAddresses,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isAddingNewAddress = false;
                                });
                              }
                            }
                          },
                    label: _isAddingNewAddress
                        ? const SizedBox(
                            width: 50,
                            height: 16,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color.fromARGB(255, 28, 143, 243),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context)?.addNew ?? 'Add New',
                            style: GoogleFonts.poppins(
                              color: const Color.fromARGB(255, 28, 143, 243),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    icon: _isAddingNewAddress
                        ? const SizedBox.shrink()
                        : const Icon(
                            Icons.add,
                            color: Color.fromARGB(255, 28, 143, 243),
                            size: 20,
                          ),
                  ),
                ],
              ),
              if (addresses.isNotEmpty) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final isSelected = address.isSelected ?? false;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: GestureDetector(
                        onTap: _isRemovingAddress
                            ? null
                            : () {
                                final updatedAddresses = addresses
                                    .map(
                                      (addr) => addr.id == address.id
                                          ? addr.copyWith(isSelected: true)
                                          : addr.copyWith(isSelected: false),
                                    )
                                    .toList();

                                Navigator.of(context).pop(
                                  AddressSheetResult(
                                    selectedAddress: address.copyWith(
                                      isSelected: true,
                                    ),
                                    updatedAddresses: updatedAddresses,
                                  ),
                                );

                                Future.microtask(() {
                                  if (context.mounted) {
                                    context.read<AddressBloc>().add(
                                      SelectAddress(address),
                                    );
                                  }
                                });
                              },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      Colors.blue[50]!,
                                      Colors.blue[100]!.withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [Colors.white, Colors.grey[50]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue[400]!
                                  : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? Colors.blue[200]!.withOpacity(0.4)
                                    : Colors.grey[300]!.withOpacity(0.2),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 2),
                                spreadRadius: isSelected ? 1 : 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue[500]
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[600],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              address.fullName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? Colors.blue[800]
                                                    : Colors.grey[800],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              address.streetName ?? '',
                                              style: GoogleFonts.poppins(
                                                color: isSelected
                                                    ? Colors.blue[600]
                                                    : Colors.grey[500],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        child: PopupMenuButton(
                                          icon: Icon(
                                            Icons.more_vert_rounded,
                                            color: isSelected
                                                ? Colors.blue[600]
                                                : Colors.grey[600],
                                            size: 20,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 8,
                                          shadowColor: Colors.black26,
                                          itemBuilder: (context) {
                                            return [
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: Colors.red[400],
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      AppLocalizations.of(
                                                            context,
                                                          )?.removeAddress ??
                                                          "",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            color:
                                                                Colors.red[400],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ];
                                          },
                                          onSelected: (value) {
                                            if (value == 'remove' &&
                                                !_isRemovingAddress) {
                                              _removeAddress(address);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (address.streetName != null &&
                                      address.streetName!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            isSelected
                                                ? Colors.blue[200]!.withOpacity(
                                                    0.3,
                                                  )
                                                : Colors.grey[200]!.withOpacity(
                                                    0.3,
                                                  ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    AppLocalizations.of(context)?.pleaseAddANewAddress ??
                        'Please add a new address.',
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(255, 79, 79, 79),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              textDirection: Directionality.of(context),
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.selectServiceAddress ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textDirection: Directionality.of(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color.fromARGB(255, 224, 224, 224),
          ),
          Flexible(
            child: BlocConsumer<AddressBloc, AddressState>(
              listener: (context, state) {
                if (state is AddressError) {
                  setState(() {
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AddressLoaded) {
                  _currentAddresses = state.addresses;
                }
                return _buildAddressList(_currentAddresses);
              },
            ),
          ),
        ],
      ),
    );
  }
}
