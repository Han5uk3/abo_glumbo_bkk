import 'dart:developer';

import 'package:abo_glumbo_bbk/common_widgets/location_map_picker.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddressSaveSheet extends StatefulWidget {
  final List<AddressModel> savedAddresses;
  Function(AddressModel)? onAddressSelected;
  Map<String, dynamic> initialPosition;

  AddressSaveSheet({
    super.key,
    this.savedAddresses = const [],
    this.onAddressSelected,
    this.initialPosition = const {'latitude': 0.0, 'longitude': 0.0},
  });

  @override
  State<AddressSaveSheet> createState() => _AddressSaveSheetState();
}

class _AddressSaveSheetState extends State<AddressSaveSheet> {
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  late List<AddressModel> _localAddressList;
  @override
  void initState() {
    _localAddressList = [...widget.savedAddresses];
    super.initState();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  void _removeAddress(AddressModel address) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await AppServices.removeAddress(address.id);

    setState(() {
      _localAddressList.remove(address);
    });

    Navigator.pop(context);

    Navigator.pop(context, {
      'selectedAddress': null,
      'addressList': _localAddressList,
    });
  }

  void _selectAddress(AddressModel address) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      bool success = await AppServices.selectLocation(address.id);
      if (success) {
        setState(() {
          for (var addr in _localAddressList) {
            addr.isSelected = false;
          }
          final index = _localAddressList.indexWhere(
            (addr) => addr.id == address.id,
          );
          if (index != -1) {
            _localAddressList[index].isSelected = true;
          }
        });
        Navigator.pop(context);
        Navigator.pop(context, {
          'selectedAddress': address,
          'addressList': _localAddressList,
        });
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select address'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting address: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.selectServiceAddress ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        child: Text(
                          AppLocalizations.of(context)?.savedAddresses ??
                              'Pick the address where you need the service.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          log(
                            "📤 AddressSaveSheet: Opening LocationMapPicker...",
                          );
                          final newAddress = await Navigator.push<AddressModel>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LocationMapPicker(
                                userLatitude: widget.initialPosition['lat'],
                                userLongitude: widget.initialPosition['lon'],
                              ),
                            ),
                          );

                          if (newAddress != null) {
                            // Optional: deselect others
                            for (var addr in _localAddressList) {
                              addr.isSelected = false;
                            }
                            newAddress.isSelected = true;
                            _localAddressList.add(newAddress);

                            Navigator.pop(context, {
                              'selectedAddress': newAddress,
                              'addressList': _localAddressList,
                            }); // ✅ Pass new address to AddIssueImageAndVideo
                          } else {
                            log(
                              "❌ AddressSaveSheet: No address received from LocationMapPicker.",
                            );
                          }
                        },
                        label: Text(
                          AppLocalizations.of(context)?.addNew ?? 'Add New',
                          style: GoogleFonts.poppins(
                            color: const Color.fromARGB(255, 28, 143, 243),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(
                          Icons.add,
                          color: Color.fromARGB(255, 28, 143, 243),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (_localAddressList.isNotEmpty) ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _localAddressList.length,
                      itemBuilder: (context, index) {
                        final address = _localAddressList[index];
                        final isSelected = address.isSelected ?? false;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: GestureDetector(
                            onTap: () => _selectAddress(address),
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
                                        colors: [
                                          Colors.white,
                                          Colors.grey[50]!,
                                        ],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: PopupMenuButton(
                                              icon: Icon(
                                                Icons.more_vert_rounded,
                                                color: isSelected
                                                    ? Colors.blue[600]
                                                    : Colors.grey[600],
                                                size: 20,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                                          color:
                                                              Colors.red[400],
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          AppLocalizations.of(
                                                                context,
                                                              )?.removeAddress ??
                                                              "",
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .red[400],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ];
                                              },
                                              onSelected: (value) {
                                                if (value == 'remove') {
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
                                          margin: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                isSelected
                                                    ? Colors.blue[200]!
                                                          .withOpacity(0.3)
                                                    : Colors.grey[200]!
                                                          .withOpacity(0.3),
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
                  const SizedBox(height: 10),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
