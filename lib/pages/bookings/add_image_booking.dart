import 'dart:io';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart' show LocalStoreHelper;
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart'
    show AccountState, AccountBloc, CustomerDataLoaded;
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/location_service.dart';
import 'package:abo_glumbo_bbk/sheets/save_address_sheet.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AddIssueImageAndVideo extends StatefulWidget {
  final ValueChanged<File?>? onImageSelected;
  final ValueChanged<File?>? onVideoSelected;
  final ValueChanged<AddressModel?>? isAddressSelected;
  List<AddressModel>? savedAddresses;
  AddIssueImageAndVideo({
    super.key,
    this.onImageSelected,
    this.onVideoSelected,
    this.isAddressSelected,
    required this.savedAddresses,
  });

  @override
  State<AddIssueImageAndVideo> createState() => _AddIssueImageAndVideoState();
}

class _AddIssueImageAndVideoState extends State<AddIssueImageAndVideo> {
  File? _selectedImage;
  File? _selectedVideo;
  final ImagePicker _picker = ImagePicker();
  bool isLoadingImage = false;
  bool isLoadingVideo = false;
  bool isUploadedImageSuccess = false;
  bool isUploadedVideoSuccess = false;
  AddressModel? _selectedAddress;
  CustomerModel? customerData;
  Map<String, dynamic> _initialPosition = {
    "lon": 0.0,
    "lat": 0.0,
    "userLocation": "",
  };
  List<AddressModel> _localAddressList = [];
  bool _hasRecentlyUpdatedFromSheet = false; // Flag to prevent stream override
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      if (widget.onImageSelected != null) {
        widget.onImageSelected!(_selectedImage);
      }
    }
  }

  Future<void> _pickVideo() async {
    final XFile? pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
      if (widget.onVideoSelected != null) {
        widget.onVideoSelected!(_selectedVideo);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
    });
  }

  Future<void> _fetchCoordinatesAndGetCustomerAddress() async {
    try {
      final coordinates = await LocationService().getUserCoordinates();
      if (mounted) {
        setState(() {
          _initialPosition = coordinates;
        });
      }
    } catch (error) {
      if (mounted) {
        return;
      }
    }
  }

  void _showAddressSheet() async {
    bool isRTL = Directionality.of(context) == TextDirection.rtl;
    debugPrint(
      "📤 AddIssueImageAndVideo: Opening address sheet with ${_localAddressList.length} addresses (RTL: $isRTL)",
    );

    try {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AddressSaveSheet(
            savedAddresses: _localAddressList,
            initialPosition: _initialPosition,
          ),
        ),
      );

      debugPrint("📍 AddIssueImageAndVideo: Address sheet result: $result");

      if (result != null) {
        final AddressModel? selectedAddress =
            result['selectedAddress'] as AddressModel?;
        final List<AddressModel> updatedAddresses = result['addressList'];

        debugPrint(
          "📍 AddIssueImageAndVideo: Selected address: ${selectedAddress?.fullName} (Arabic: ${selectedAddress?.fullName.contains(RegExp(r'[\u0600-\u06FF]'))})",
        );

        // Update immediately without delays or complex timing
        setState(() {
          _localAddressList = [...updatedAddresses];
          _selectedAddress = selectedAddress;
        });

        // Notify parent immediately
        if (widget.isAddressSelected != null && selectedAddress != null) {
          widget.isAddressSelected!(selectedAddress);
        }

        debugPrint(
          "📍 AddIssueImageAndVideo: Updated UI with new address: ${selectedAddress?.fullName} (Local list size: ${_localAddressList.length})",
        );
      } else {
        // No result, but still refresh to get any new addresses
        debugPrint(
          "📍 AddIssueImageAndVideo: No result, refreshing addresses...",
        );
        await _refreshAddressesFromDatabase();
      }
    } catch (e) {
      debugPrint("❌ AddIssueImageAndVideo: Error in address sheet: $e");
    }
  }

  Future<void> _refreshAddressesFromDatabase() async {
    try {
      debugPrint(
        "📍 AddIssueImageAndVideo: Refreshing addresses from database...",
      );

      // Get fresh customer data
      final uid = LocalStoreHelper.getUID();
      if (uid != null) {
        final customerData = await AppServices.fetchCustomerData(uid: uid);
        if (customerData.addresses.isNotEmpty) {
          setState(() {
            _localAddressList = [...customerData.addresses];

            // Find the selected address or use the most recent one
            try {
              _selectedAddress = _localAddressList.firstWhere(
                (address) => address.isSelected == true,
              );
            } catch (e) {
              // If no selected address, use the last one (most recently added)
              _selectedAddress = _localAddressList.last;
            }
          });

          // Notify parent of the updated selection
          if (widget.isAddressSelected != null && _selectedAddress != null) {
            widget.isAddressSelected!(_selectedAddress);
          }

          debugPrint(
            "📍 AddIssueImageAndVideo: Refreshed ${_localAddressList.length} addresses, selected: ${_selectedAddress?.fullName}",
          );
        }
      }
    } catch (e) {
      debugPrint("❌ AddIssueImageAndVideo: Error refreshing addresses: $e");
    }
  }

  AddressModel? _getSelectedAddress() {
    debugPrint(
      "📍 AddIssueImageAndVideo: Getting selected address from ${_localAddressList.length} addresses",
    );

    if (_localAddressList.isNotEmpty) {
      // First, log all addresses and their selection status
      for (int i = 0; i < _localAddressList.length; i++) {
        final addr = _localAddressList[i];
        debugPrint(
          "📍 Address $i: ${addr.fullName} - Selected: ${addr.isSelected}",
        );
      }

      try {
        _selectedAddress = _localAddressList.firstWhere(
          (address) => address.isSelected == true,
        );
        debugPrint(
          "📍 AddIssueImageAndVideo: Found selected address: ${_selectedAddress?.fullName}",
        );
      } catch (e) {
        // If no address is selected, try to get the first one as default
        debugPrint(
          "📍 AddIssueImageAndVideo: No selected address found, trying first address",
        );
        if (_localAddressList.isNotEmpty) {
          _selectedAddress = _localAddressList.first;
          debugPrint(
            "📍 AddIssueImageAndVideo: Using first address as default: ${_selectedAddress?.fullName}",
          );
        } else {
          _selectedAddress = null;
        }
      }
    } else {
      debugPrint("📍 AddIssueImageAndVideo: No addresses available");
      _selectedAddress = null;
    }

    // Notify parent widget about address selection
    if (widget.isAddressSelected != null) {
      widget.isAddressSelected!(_selectedAddress);
    }
    return _selectedAddress;
  }

  Widget _addMediaWidget({
    required bool isImage,
    required File? file,
    required void Function() onPick,
    required void Function() onRemove,
  }) {
    bool isUploaded = isImage ? isUploadedImageSuccess : isUploadedVideoSuccess;

    return GestureDetector(
      onTap: (isUploaded ? null : onPick),
      child: DottedBorder(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x805C9BE8),
            borderRadius: BorderRadius.circular(10),
          ),
          width: MediaQuery.of(context).size.width * 0.4,
          height: 100,
          child: Center(
            child: file == null
                ? isImage
                      ? Image.asset(
                          "assets/images/image.png",
                          width: 30,
                          height: 30,
                        )
                      : Image.asset(
                          "assets/images/upload.png",
                          width: 30,
                          height: 30,
                        )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isImage
                              ? Image.file(file, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.black,
                                  child: Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: !isUploaded
                            ? GestureDetector(
                                onTap: onRemove,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : SizedBox(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    _initializeAddresses();
    _fetchCoordinatesAndGetCustomerAddress();
    super.initState();
  }

  @override
  void didUpdateWidget(AddIssueImageAndVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if savedAddresses prop has changed, but only update if we haven't recently updated from sheet
    if (widget.savedAddresses != oldWidget.savedAddresses &&
        !_hasRecentlyUpdatedFromSheet) {
      debugPrint(
        "📍 AddIssueImageAndVideo: savedAddresses prop updated from ${oldWidget.savedAddresses?.length} to ${widget.savedAddresses?.length}",
      );
      _localAddressList = [...widget.savedAddresses ?? []];
      _getSelectedAddress();
    } else if (_hasRecentlyUpdatedFromSheet) {
      debugPrint(
        "📍 AddIssueImageAndVideo: Skipping prop update due to recent sheet update",
      );
    }
  }

  void _initializeAddresses() {
    _localAddressList = [...widget.savedAddresses ?? []];
    _getSelectedAddress();
    debugPrint(
      "📍 AddIssueImageAndVideo: Initialized with ${_localAddressList.length} addresses",
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        if (state is CustomerDataLoaded && !_hasRecentlyUpdatedFromSheet) {
          final customerData = state.customerData;
          // Update local addresses when customer data changes, but preserve current selection
          if (customerData.addresses.isNotEmpty) {
            debugPrint(
              "📍 AddIssueImageAndVideo: Customer data loaded with ${customerData.addresses.length} addresses",
            );

            // Only update if the address count is different or if we have no addresses locally
            if (_localAddressList.length != customerData.addresses.length ||
                _localAddressList.isEmpty) {
              final currentSelectedId = _selectedAddress?.id;
              _localAddressList = [...customerData.addresses];

              // Try to preserve the current selection, or get the selected one from the data
              if (currentSelectedId != null) {
                try {
                  _selectedAddress = _localAddressList.firstWhere(
                    (addr) => addr.id == currentSelectedId,
                  );
                  debugPrint(
                    "📍 AddIssueImageAndVideo: Preserved selected address: ${_selectedAddress?.fullName}",
                  );
                } catch (e) {
                  // If the current selection is not found, get the selected one from data
                  _getSelectedAddress();
                }
              } else {
                _getSelectedAddress();
              }
            }
          }
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            locationDetection(_localAddressList, _selectedAddress),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(
                top: 10,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              child: heading(
                AppLocalizations.of(context)?.visualizeYourIssue ?? '',
                AppLocalizations.of(context)?.addImageOrVideoOfIssue ?? '',
              ),
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _addMediaWidget(
                  file: _selectedImage,
                  isImage: true,
                  onPick: _pickImage,
                  onRemove: _removeImage,
                ),
                _addMediaWidget(
                  file: _selectedVideo,
                  isImage: false,
                  onPick: _pickVideo,
                  onRemove: _removeVideo,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget heading(String heading, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 79, 79, 79),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget locationDetection(
    List<AddressModel> savedAddresses,
    AddressModel? selectedAddress,
  ) {
    debugPrint(
      "📍 LocationDetection: Saved addresses: ${savedAddresses.length}, Selected: ${selectedAddress?.fullName}",
    );

    bool isRTL = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      onTap: () => _showAddressSheet(),
      child: Container(
        padding: EdgeInsets.only(
          top: 10,
          bottom: 10,
          left: (selectedAddress != null) ? (isRTL ? 10 : 2) : 10,
          right: (selectedAddress != null) ? (isRTL ? 2 : 10) : 10,
        ),
        margin: EdgeInsets.only(left: isRTL ? 25 : 16, right: isRTL ? 16 : 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color.fromARGB(255, 221, 221, 221),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: selectedAddress != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            if (selectedAddress == null)
              Icon(
                Icons.location_on_rounded,
                color: const Color.fromARGB(255, 79, 79, 79),
              ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: isRTL
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (selectedAddress != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: isRTL
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.serviceto ??
                              'Service to:',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: isRTL
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                        InkWell(
                          onTap: () => _showAddressSheet(),
                          child: Container(
                            width: 70,
                            height: 25,
                            decoration: BoxDecoration(
                              color: Colors.blue[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)?.change ??
                                    'Change',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection: isRTL
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedAddress.fullName,
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 149, 149, 149),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      textDirection: isRTL
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                    Text(
                      selectedAddress.streetName?.isNotEmpty == true
                          ? selectedAddress.streetName!
                          : selectedAddress.buildingNumber.isNotEmpty
                          ? selectedAddress.buildingNumber
                          : "Address location",
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 149, 149, 149),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection: isRTL
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ] else ...[
                    Text(
                      savedAddresses.isNotEmpty
                          ? (AppLocalizations.of(
                                  context,
                                )?.selectServiceAddress ??
                                'Select Service Address')
                          : (AppLocalizations.of(
                                  context,
                                )?.chooseServiceAddress ??
                                'Choose Service Address'),
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 79, 79, 79),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: isRTL
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      savedAddresses.isNotEmpty
                          ? (AppLocalizations.of(
                                  context,
                                )?.selectFromSavedAddresses ??
                                'Select from your saved addresses or add a new one.')
                          : (AppLocalizations.of(context)?.pickServiceAddress ??
                                'Pick the address where you need the service.'),
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 149, 149, 149),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection: isRTL
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ],
                ],
              ),
            ),
            if (selectedAddress == null)
              Icon(
                isRTL
                    ? Icons.arrow_back_ios_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: const Color.fromARGB(255, 79, 79, 79),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
