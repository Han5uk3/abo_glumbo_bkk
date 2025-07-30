import 'dart:io';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart'
    show AccountState, AccountBloc, CustomerDataLoaded;
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

    if (result != null) {
      final AddressModel? selectedAddress =
          result['selectedAddress'] as AddressModel?;
      final List<AddressModel> updatedAddresses = result['addressList'];

      setState(() {
        _selectedAddress = selectedAddress;
        _localAddressList = updatedAddresses;
      });

      if (widget.isAddressSelected != null) {
        widget.isAddressSelected!(selectedAddress);
      }
    }
  }

  AddressModel? _getSelectedAddress() {
    if (_localAddressList.isNotEmpty) {
      try {
        _selectedAddress = _localAddressList.firstWhere(
          (address) => address.isSelected == true,
        );
      } catch (e) {
        _selectedAddress = null;
      }
    }
    if (_selectedAddress != null) {
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
    _localAddressList = [...widget.savedAddresses ?? []];
    _getSelectedAddress();
    _fetchCoordinatesAndGetCustomerAddress();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        if (state is CustomerDataLoaded) {
          final customerData = state.customerData;
          if (customerData != null) {
            _localAddressList = customerData.addresses;
            _getSelectedAddress();
          }
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            locationDetection(customerData?.addresses ?? [], _selectedAddress),
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
    return GestureDetector(
      onTap: (selectedAddress == null) ? () => _showAddressSheet() : null,
      child: Container(
        padding: EdgeInsets.only(
          top: 10,
          bottom: 10,
          left: (selectedAddress != null) ? 2 : 10,
          right: 10,
        ),
        margin: const EdgeInsets.only(left: 16, right: 25),
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
          children: [
            if (selectedAddress == null && savedAddresses.isEmpty)
              Icon(
                Icons.location_on_rounded,
                color: const Color.fromARGB(255, 79, 79, 79),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedAddress != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.serviceto ??
                              'Service to:',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
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
                    ),
                    Text(
                      selectedAddress.streetName ?? "",
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 149, 149, 149),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Text(
                      AppLocalizations.of(context)?.chooseServiceAddress ??
                          'Choose Service Address',
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 79, 79, 79),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)?.pickServiceAddress ??
                          'Pick the address where you need the service.',
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 149, 149, 149),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selectedAddress == null && savedAddresses.isEmpty)
              Icon(
                Directionality.of(context) == TextDirection.rtl
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
