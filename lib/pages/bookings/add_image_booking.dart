import 'dart:async';
import 'dart:io';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/address_result.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/address_bloc.dart';
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

  const AddIssueImageAndVideo({
    super.key,
    this.onImageSelected,
    this.onVideoSelected,
    this.isAddressSelected,
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
  bool _hasRecentlyUpdatedFromSheet = false;

  Timer? _sheetUpdateTimer;

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
      debugPrint("Error fetching coordinates: $error");
    }
  }

  Future<void> _showAddressSheet(
    BuildContext context,
    List<AddressModel> savedAddresses, {
    bool isChangingAddress = false,
  }) async {
    final result = await showModalBottomSheet<AddressSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AddressSaveSheet(
        initialPosition: _initialPosition,
        isChangingAddress: isChangingAddress,
      ),
    );

    context.read<AddressBloc>().add(LoadAddresses());

    if (result != null) {
      if (result.needsAddressSelection) {
        _hasRecentlyUpdatedFromSheet = true;
        setState(() {
          _selectedAddress = null;
        });
        widget.isAddressSelected?.call(null);
        return;
      }

      final selected = result.selectedAddress;
      if (selected != null) {
        _hasRecentlyUpdatedFromSheet = true;

        setState(() {
          _selectedAddress = selected;
        });
        widget.isAddressSelected?.call(selected);
      }
    }
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
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (!isUploaded)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
    super.initState();
    context.read<AddressBloc>().add(LoadAddresses());
    _fetchCoordinatesAndGetCustomerAddress();
  }

  @override
  void dispose() {
    _sheetUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddressBloc, AddressState>(
      listener: (context, state) {
        if (state is AddressLoaded) {
          final selected = state.selected;

          if (_hasRecentlyUpdatedFromSheet) {
            if (_selectedAddress != null) {
              widget.isAddressSelected?.call(_selectedAddress);
            } else {
              widget.isAddressSelected?.call(null);
            }
          } else {
            if (selected != null) {
              setState(() {
                _selectedAddress = selected;
              });
              widget.isAddressSelected?.call(selected);
            } else {
              setState(() {
                _selectedAddress = null;
              });
              widget.isAddressSelected?.call(null);
            }
          }

          if (_hasRecentlyUpdatedFromSheet) {
            _sheetUpdateTimer?.cancel();
            _sheetUpdateTimer = Timer(const Duration(milliseconds: 500), () {
              _hasRecentlyUpdatedFromSheet = false;
            });
          }
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          BlocBuilder<AddressBloc, AddressState>(
            builder: (context, state) {
              List<AddressModel> addresses = [];
              AddressModel? selected = _selectedAddress;
              if (state is AddressLoaded) {
                addresses = state.addresses;

                selected ??= state.selected;
              }
              return locationDetection(addresses, selected);
            },
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 5),
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
      ),
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
    final bool isRTL = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      onTap: selectedAddress != null
          ? null
          : () => _showAddressSheet(context, savedAddresses),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.only(left: isRTL ? 25 : 16, right: isRTL ? 16 : 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: selectedAddress != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            if (selectedAddress == null)
              Padding(
                padding: EdgeInsets.only(
                  left: isRTL ? 8 : 0,
                  right: isRTL ? 0 : 8,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: const Color(0xFF4F4F4F),
                  size: 20,
                ),
              ),

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
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)?.serviceto ??
                                'Service to:',
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showAddressSheet(
                            context,
                            savedAddresses,
                            isChangingAddress: true,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.change ?? 'Change',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      selectedAddress.fullName,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2C2C2C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 2),

                    Text(
                      selectedAddress.streetName?.isNotEmpty == true
                          ? selectedAddress.streetName!
                          : selectedAddress.buildingNumber.isNotEmpty
                          ? selectedAddress.buildingNumber
                          : "Address location",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF959595),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
                        color: const Color(0xFF4F4F4F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      savedAddresses.isNotEmpty
                          ? (AppLocalizations.of(
                                  context,
                                )?.selectFromSavedAddresses ??
                                'Select from your saved addresses or add a new one.')
                          : (AppLocalizations.of(context)?.pickServiceAddress ??
                                'Pick the address where you need the service.'),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF959595),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ],
                ],
              ),
            ),

            if (selectedAddress == null)
              Padding(
                padding: EdgeInsets.only(
                  left: isRTL ? 0 : 8,
                  right: isRTL ? 8 : 0,
                ),
                child: Transform.rotate(
                  angle: isRTL ? 3.14159 : 0,
                  child: Icon(
                    isRTL
                        ? Icons.arrow_back_ios_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF4F4F4F),
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
