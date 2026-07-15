import 'dart:async';
import 'dart:io';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/address_result.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/address_bloc.dart';
import 'package:abo_glumbo_bbk/services/location_service.dart';
import 'package:abo_glumbo_bbk/sheets/save_address_sheet.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class AddIssueImageAndVideo extends StatefulWidget {
  final ValueChanged<File?>? onImageSelected;
  final ValueChanged<File?>? onVideoSelected;
  final VoidCallback? onImageRemoved;
  final VoidCallback? onVideoRemoved;
  final ValueChanged<AddressModel?>? isAddressSelected;
  final bool showAddressPicker;
  final File? initialImage;
  final File? initialVideo;
  final String? initialImageUrl;
  final String? initialVideoUrl;

  const AddIssueImageAndVideo({
    super.key,
    this.onImageSelected,
    this.onVideoSelected,
    this.onImageRemoved,
    this.onVideoRemoved,
    this.isAddressSelected,
    this.showAddressPicker = true,
    this.initialImage,
    this.initialVideo,
    this.initialImageUrl,
    this.initialVideoUrl,
  });

  @override
  State<AddIssueImageAndVideo> createState() => _AddIssueImageAndVideoState();
}

class _AddIssueImageAndVideoState extends State<AddIssueImageAndVideo> {
  File? _selectedImage;
  File? _selectedVideo;
  String? _networkImageUrl;
  String? _networkVideoUrl;

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

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        if (widget.onImageSelected != null) {
          widget.onImageSelected!(_selectedImage);
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorOccurred ??
                  'An error occurred while picking the image',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideoFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(source: source);

      if (pickedFile != null) {
        setState(() {
          _selectedVideo = File(pickedFile.path);
        });
        if (widget.onVideoSelected != null) {
          widget.onVideoSelected!(_selectedVideo);
        }
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorOccurred ??
                  'An error occurred while picking the video',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _networkImageUrl = null;
    });
    if (widget.onImageRemoved != null) {
      widget.onImageRemoved!();
    }
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
      _networkVideoUrl = null;
    });
    if (widget.onVideoRemoved != null) {
      widget.onVideoRemoved!();
    }
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
    String? networkUrl,
    required void Function() onPick,
    required void Function() onRemove,
  }) {
    bool isUploaded = isImage ? isUploadedImageSuccess : isUploadedVideoSuccess;

    return GestureDetector(
      onTap: (isUploaded
          ? null
          : () => _showMediaSourcePicker(isVideo: !isImage)),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: Radius.circular(10),
          color: Colors.black12,
          strokeWidth: 2,
          dashPattern: const [6, 2],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          width: (MediaQuery.of(context).size.width - 52) * 0.5,
          height: 100,
          child: Center(
            child: (file == null && networkUrl == null)
                ? isImage
                      ? Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Colors.grey,
                            size: 30,
                          ),
                        )
                      : Center(
                          child: Image.asset(
                            colorBlendMode: BlendMode.srcIn,
                            color: Colors.grey,
                            "assets/icons/add-movie.png",
                            width: 30,
                            height: 30,
                          ),
                        )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isImage
                              ? (file != null 
                                  ? Image.file(file, fit: BoxFit.cover)
                                  : Image.network(networkUrl!, fit: BoxFit.cover))
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
    _selectedImage = widget.initialImage;
    _selectedVideo = widget.initialVideo;
    _networkImageUrl = widget.initialImageUrl;
    _networkVideoUrl = widget.initialVideoUrl;
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
          Padding(
            padding: const EdgeInsets.only(
              top: 10,
              left: 0,
              right: 0,
              bottom: 4,
            ),
            child: heading(
              AppLocalizations.of(context)?.visualizeYourIssue ?? '',
            ),
          ),
          Text(
            AppLocalizations.of(context)?.visualizeYourIssueSubtitle ??
                'Photos and videos help the technician prepare and save your time.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _addMediaWidget(
                file: _selectedImage,
                networkUrl: _networkImageUrl,
                isImage: true,
                onPick: () => _showMediaSourcePicker(isVideo: false),
                onRemove: _removeImage,
              ),
              _addMediaWidget(
                file: _selectedVideo,
                networkUrl: _networkVideoUrl,
                isImage: false,
                onPick: () => _showMediaSourcePicker(isVideo: true),
                onRemove: _removeVideo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget heading(String heading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.normal,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedAddress != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.serviceto,
                            style: TextStyle(
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
                              savedAddresses.isEmpty
                                  ? AppLocalizations.of(context)!.add
                                  : (AppLocalizations.of(context)?.change ??
                                        'Change'),
                              style: TextStyle(
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
                      style: TextStyle(
                        color: const Color(0xFF2C2C2C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 2),

                    Text(
                      (selectedAddress.buildingNumber.isNotEmpty ||
                              selectedAddress.streetName?.isNotEmpty == true)
                          ? "${selectedAddress.buildingNumber.isNotEmpty ? '${selectedAddress.buildingNumber}, ' : ''}${selectedAddress.streetName ?? ''}"
                          : "Address location",
                      style: TextStyle(
                        color: const Color(0xFF959595),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.start,
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
                      style: TextStyle(
                        color: const Color(0xFF4F4F4F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
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
                      style: TextStyle(
                        color: const Color(0xFF959595),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.start,
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

  Future<void> _showMediaSourcePicker({required bool isVideo}) async {
    final bool isRTL = Directionality.of(context) == TextDirection.rtl;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                height: 4,
                width: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // Title with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isVideo
                        ? (AppLocalizations.of(context)?.selectVideoSource ??
                              'Select Video Source')
                        : (AppLocalizations.of(context)?.selectImageSource ??
                              'Select Image Source'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                AppLocalizations.of(context)?.chooseSource ?? 'Choose a source',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 32),

              // Options with elevated design
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildElegantSourceOption(
                    icon: Icons.camera_alt_outlined,
                    label: AppLocalizations.of(context)?.camera ?? 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      if (isVideo) {
                        _pickVideoFromSource(ImageSource.camera);
                      } else {
                        _pickImageFromSource(ImageSource.camera);
                      }
                    },
                    isRTL: isRTL,
                  ),
                  const SizedBox(width: 16),
                  _buildElegantSourceOption(
                    icon: Icons.photo_library_outlined,
                    label: AppLocalizations.of(context)?.gallery ?? 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      if (isVideo) {
                        _pickVideoFromSource(ImageSource.gallery);
                      } else {
                        _pickImageFromSource(ImageSource.gallery);
                      }
                    },
                    isRTL: isRTL,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildElegantSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isRTL,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2C2C2C),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
