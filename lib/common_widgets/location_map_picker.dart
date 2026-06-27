import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:abo_glumbo_bbk/apis/place_suggestion_api.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/location_card.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationMapPicker extends StatefulWidget {
  final double? userLatitude;
  final double? userLongitude;
  final Function(AddressModel)? onAddressSelected;
  final Function(Map<String, dynamic>)? onLocationSelected;
  final bool isFromHomeAddress;
  final AddressModel? existingAddress;

  const LocationMapPicker({
    super.key,
    this.userLatitude,
    this.userLongitude,
    this.onAddressSelected,
    this.onLocationSelected,
    this.isFromHomeAddress = false,
    this.existingAddress,
  });

  @override
  State<LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends State<LocationMapPicker> {
  GoogleMapController? mapController;
  late LatLng _initialPosition;
  LatLng? _selectedLocation;
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _predictions = [];
  bool _isLoading = false;
  bool _mapReady = false;
  Timer? _debounceTimer;

  final _buildingNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isAddingAddress = false;
  final _formKey = GlobalKey<FormState>();

  String _locationTitle = '';
  String _locationSubtitle = '';

  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    log("populating Controllers");

    _populateControllers();

    if (widget.existingAddress == null) {
      _checkLocationPermissionsOnOpen();
    }
  }

  Future<void> _checkLocationPermissionsOnOpen() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      log("Error checking location permissions: $e");
    }
  }

  Future<void> _populateControllers() async {
    if (widget.existingAddress != null) {
      _fullNameController.text = widget.existingAddress!.fullName;
      _phoneNumberController.text = widget.existingAddress!.phoneNumber;
      _buildingNameController.text = widget.existingAddress!.buildingNumber;
      _locationTitle = widget.existingAddress!.streetName ?? '';
      return;
    }

    log("getting user details");
    try {
      final uid = LocalStoreHelper.getUID();
      if (uid == null || uid.isEmpty) {
        log("⚠️ No UID found, skipping user details fetch");
        return;
      }

      final userDoc = await AppFirestore.customersCollectionRef.doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        log("got user details: ${data.toString()}");
        if (data != null && mounted) {
          setState(() {
            _phoneNumberController.text = data['phone'] ?? '';
          });
        }
      }
    } catch (e) {
      log("❌ Error fetching user details: $e");
    }
  }

  void _initializeLocation() {
    const defaultLat = 12.9716;
    const defaultLng = 77.5946;

    if (widget.existingAddress != null) {
      _initialPosition = LatLng(
        widget.existingAddress!.lat ?? defaultLat,
        widget.existingAddress!.lon ?? defaultLng,
      );
    } else {
      _initialPosition = LatLng(
        widget.userLatitude ?? defaultLat,
        widget.userLongitude ?? defaultLng,
      );
    }
    _selectedLocation = _initialPosition;
  }

  void _onMapCreated(GoogleMapController controller) {
    log("[MAP_DEBUG] 🗺️ onMapCreated triggered for LocationMapPicker");
    mapController = controller;
    setState(() {
      _mapReady = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      log(
        "[MAP_DEBUG] 📍 Centering camera on: ${_selectedLocation?.latitude}, ${_selectedLocation?.longitude}",
      );
      _moveCameraToLocation(_selectedLocation!, animate: false);
      _getAddressFromLatLng(_selectedLocation!, showLoader: true);
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          AppLocalizations.of(context)?.locationServicesDisabled ??
              'Location services are disabled',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
            AppLocalizations.of(context)?.locationPermissionDenied ??
                'Location permissions are denied',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          AppLocalizations.of(context)?.locationPermissionDeniedForever ??
              'Location permissions are permanently denied',
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLocation;
      });

      await _moveCameraToLocation(currentLocation);
      await _getAddressFromLatLng(currentLocation, showLoader: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.couldNotGetCurrentLocation ??
                  'Could not get current location: ${e.toString()}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _parseAddress(String fullAddress, Placemark? placemark) {
    if (fullAddress.isEmpty) {
      _locationTitle =
          AppLocalizations.of(context)?.selectedLocation ?? 'Selected Location';
      _locationSubtitle = '';
      return;
    }
    String title = '';
    if (placemark != null) {
      if (placemark.name != null &&
          placemark.name!.isNotEmpty &&
          placemark.name != placemark.street &&
          placemark.name != placemark.subLocality &&
          placemark.name != placemark.locality) {
        title = placemark.name!;
      } else if (placemark.subLocality != null &&
          placemark.subLocality!.isNotEmpty) {
        title = placemark.subLocality!;
      } else if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        title = placemark.locality!;
      } else if (placemark.street != null && placemark.street!.isNotEmpty) {
        title = placemark.street!;
      }
    }

    if (title.isEmpty) {
      List<String> addressParts = fullAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (addressParts.isNotEmpty) {
        title = addressParts[0];

        if (addressParts.length > 1 &&
            RegExp(r'^[\d\s\-\+\.]+$').hasMatch(title)) {
          title = addressParts[1];
        }
      }

      if (title.isEmpty) {
        title =
            AppLocalizations.of(context)?.selectedLocation ??
            'Selected Location';
      }
    }

    List<String> subtitleParts = [];

    if (placemark != null) {
      if (placemark.street != null &&
          placemark.street!.isNotEmpty &&
          placemark.street != title) {
        subtitleParts.add(placemark.street!);
      }

      if (placemark.subLocality != null &&
          placemark.subLocality!.isNotEmpty &&
          placemark.subLocality != title) {
        subtitleParts.add(placemark.subLocality!);
      }

      if (placemark.locality != null &&
          placemark.locality!.isNotEmpty &&
          placemark.locality != title) {
        subtitleParts.add(placemark.locality!);
      }

      if (placemark.administrativeArea != null &&
          placemark.administrativeArea!.isNotEmpty) {
        subtitleParts.add(placemark.administrativeArea!);
      }

      if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
        subtitleParts.add(placemark.postalCode!);
      }

      if (placemark.country != null && placemark.country!.isNotEmpty) {
        subtitleParts.add(placemark.country!);
      }
    } else {
      List<String> addressParts = fullAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (addressParts.length > 1) {
        subtitleParts = addressParts
            .skip(1)
            .where((part) => part != title && part.isNotEmpty)
            .toList();
      }
    }

    List<String> uniqueSubtitleParts = [];
    for (String part in subtitleParts) {
      String cleanPart = part.trim();
      if (cleanPart.isNotEmpty && !uniqueSubtitleParts.contains(cleanPart)) {
        uniqueSubtitleParts.add(cleanPart);
      }
    }
    _locationTitle = title.trim();
    _locationSubtitle = uniqueSubtitleParts.join(', ');
    if (widget.existingAddress == null) {
      _fullNameController.text = _locationTitle;
    }
  }

  Future<void> _getAddressFromLatLng(
    LatLng latLng, {
    bool showLoader = false,
  }) async {
    try {
      if (showLoader) {
        setState(() {
          _isLoading = true;
        });
      }
      List<Placemark> placemarks =
          await placemarkFromCoordinates(
            latLng.latitude,
            latLng.longitude,
          ).timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Address lookup timed out');
            },
          );
      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks[0];
        List<String> addressComponents = [];
        if (placemark.name != null && placemark.name!.isNotEmpty) {
          addressComponents.add(placemark.name!);
        }
        if (placemark.street != null &&
            placemark.street!.isNotEmpty &&
            placemark.street != placemark.name) {
          addressComponents.add(placemark.street!);
        }
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          addressComponents.add(placemark.subLocality!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressComponents.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressComponents.add(placemark.administrativeArea!);
        }
        String address = addressComponents.join(', ');
        if (address.isEmpty) {
          address =
              'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
        }
        setState(() {
          _parseAddress(address, placemark);
        });
      } else {
        if (mounted) {
          setState(() {
            String fallbackAddress =
                'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
            _locationTitle =
                AppLocalizations.of(context)?.selectedLocation ??
                'Selected Location';
            _locationSubtitle = fallbackAddress;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationTitle =
              AppLocalizations.of(context)?.selectedLocation ??
              'Selected Location';
          _locationSubtitle =
              AppLocalizations.of(context)?.unableToGetAddress ??
              'Unable to get address - ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.unableToGetAddress ??
                  'Unable to get address: ${e.toString()}',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _isLoading = false;
          _predictions.clear();
        });
      }
    }
  }

  Future<void> _searchPlaces(String input) async {
    if (input.trim().isEmpty) {
      setState(() {
        _predictions.clear();
      });
      return;
    }

    _debounceTimer?.cancel();

    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        setState(() {
          _isLoading = true;
        });

        final results = await getPlaceSuggestions(input);

        if (mounted) {
          setState(() {
            _predictions = results;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _predictions.clear();
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _moveCameraToPlace(String address) async {
    if (address.isEmpty || mapController == null) return;

    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _predictions.clear();
    });

    try {
      List<Location> locations = await locationFromAddress(address).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Location search timed out');
        },
      );

      if (locations.isNotEmpty && mounted) {
        final latLng = LatLng(locations[0].latitude, locations[0].longitude);
        await _moveCameraToLocation(latLng);
        setState(() {
          _selectedLocation = latLng;
        });
        await _getAddressFromLatLng(latLng, showLoader: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.couldNotFindLocation ??
                  'Could not find location: ${e.toString()}',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _moveCameraToLocation(
    LatLng latLng, {
    bool animate = true,
  }) async {
    if (mapController == null) return;

    final cameraUpdate = CameraUpdate.newLatLngZoom(latLng, 15);

    if (animate) {
      await mapController!.animateCamera(cameraUpdate);
    } else {
      await mapController!.moveCamera(cameraUpdate);
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _predictions.clear();
      _locationTitle =
          AppLocalizations.of(context)?.gettingAddress ?? 'Getting address...';
      _locationSubtitle = '';
    });

    _searchFocusNode.unfocus();
    _getAddressFromLatLng(latLng, showLoader: false);
  }

  void _showAddressDetailsBottomSheet() {
    bool isRTL = Directionality.of(context) == TextDirection.rtl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isRTL
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)?.serviceto ?? 'Service to',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textDirection: isRTL
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                  const SizedBox(height: 20),
                  LocationCard(
                    title: _locationTitle.isNotEmpty
                        ? _locationTitle
                        : AppLocalizations.of(context)?.selectedLocation ??
                              'Selected Location',
                    subtitle: _locationSubtitle,
                  ),
                  const SizedBox(height: 20),
                  TextFormWidget(
                    controller: _buildingNameController,
                    label: '',
                    isNeedLabel: false,
                    keyboardType: TextInputType.text,
                    hint: Text(
                      "${AppLocalizations.of(context)?.buildingName ?? 'Building Name'} (${AppLocalizations.of(context)!.optional})",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormWidget(
                    controller: _fullNameController,
                    label: '',
                    isNeedLabel: false,
                    keyboardType: TextInputType.name,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(
                          context,
                        )!.pleaseAddANameToIdentifyTheLocation;
                      }
                      return null;
                    },
                    hint: Text(
                      AppLocalizations.of(context)!.namehomeworketc,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormWidget(
                    controller: _phoneNumberController,
                    label: '',
                    isNeedLabel: false,
                    keyboardType: TextInputType.phone,
                    hint: Text(
                      AppLocalizations.of(context)?.phoneNumber ??
                          'Phone Number',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(
                              context,
                            )?.phoneNumberRequired ??
                            'Phone number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isAddingAddress
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                _saveAddressWithDetails();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                      ),
                      child: _isAddingAddress
                          ? Loader()
                          : Text(
                              AppLocalizations.of(context)?.saveAddress ??
                                  'Save Address',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveAddressWithDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isAddingAddress = true);

    try {
      if (_selectedLocation != null) {
        final newAddress = AddressModel(
          id:
              widget.existingAddress?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          streetName: _locationSubtitle.isNotEmpty
              ? _locationSubtitle
              : (_locationTitle.isNotEmpty
                    ? _locationTitle
                    : 'Selected Location'),
          buildingNumber: _buildingNameController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          lat: _selectedLocation!.latitude,
          lon: _selectedLocation!.longitude,
          isSelected: true,
        );

        if (mounted) {
          setState(() => _isAddingAddress = false);

          // Close the bottom sheet first, then the main screen
          Navigator.of(context).pop(); // This closes the bottom sheet

          // Schedule the next navigation for the next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(
                context,
              ).pop(newAddress); // This returns to AddressSaveSheet
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingAddress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.errorSavingAddress ?? 'Error saving address'}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Loader(color: AppColors.primary, size: 20)),
      );
    }

    if (_predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: _predictions.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  _predictions[index],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                leading: Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                onTap: () => _moveCameraToPlace(_predictions[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.chooseLocation ?? 'Choose Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (!_mapReady) Center(child: Loader(color: AppColors.primary)),
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 14,
                  ),
                  onTap: _onMapTap,
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId("selected"),
                            position: _selectedLocation!,
                            infoWindow: InfoWindow(
                              title: _locationTitle.isNotEmpty
                                  ? _locationTitle
                                  : AppLocalizations.of(
                                          context,
                                        )?.selectedLocation ??
                                        'Selected Location',
                              snippet: _locationSubtitle.isNotEmpty
                                  ? _locationSubtitle
                                  : null,
                            ),
                          ),
                        }
                      : {},
                  myLocationButtonEnabled: false,
                  myLocationEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 65,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _searchPlaces,
                              focusNode: _searchFocusNode,
                              style: TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText:
                                    AppLocalizations.of(
                                      context,
                                    )?.pickServiceAddress ??
                                    'Pick service address',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _predictions.clear();
                                          });
                                          _searchFocusNode.unfocus();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildSearchResults(),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: _getCurrentLocation,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    mini: true,
                    child: Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDistanceInfo(),
        ],
      ),
    );
  }

  Widget _buildDistanceInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.serviceto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.black1,
            ),
          ),
          const SizedBox(height: 16),
          LocationCard(
            title: _locationTitle.isNotEmpty
                ? _locationTitle
                : AppLocalizations.of(context)?.selectLocation ??
                      'Select Location',
            subtitle: _locationSubtitle,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppColors.primary,
                elevation: 0,
              ),
              onPressed: _selectedLocation != null
                  ? () => _showAddressDetailsBottomSheet()
                  : null,
              child: Text(
                AppLocalizations.of(context)?.addAddressDetails ??
                    'Add Address Details',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _buildingNameController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    mapController?.dispose();
    super.dispose();
  }
}
