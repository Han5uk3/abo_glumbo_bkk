import 'dart:async';
import 'dart:developer';
import 'package:abo_glumbo_bbk/apis/place_suggestion_api.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/location_card.dart';
import 'package:abo_glumbo_bbk/common_widgets/text_form.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/utils/poppins_font.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationMapPicker extends StatefulWidget {
  final double? userLatitude;
  final double? userLongitude;
  final Function(AddressModel)? onAddressSelected;
  final Function(Map<String, dynamic>)? onLocationSelected;
  final bool isFromHomeAddress;
  const LocationMapPicker({
    super.key,
    this.userLatitude,
    this.userLongitude,
    this.onAddressSelected,
    this.onLocationSelected,
    this.isFromHomeAddress = false,
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
  }

  _populateControllers() async {
    log("getting user details");
    final user = AppFirestore.customersCollectionRef.doc(
      LocalStoreHelper.getUID(),
    );
    user.get().then((value) {
      if (value.exists) {
        final data = value.data() as Map<String, dynamic>?;
        log("got user details: ${data.toString()}");
        if (data != null) {
          _fullNameController.text = data['name'] ?? '';
          _phoneNumberController.text = data['phone'] ?? '';
        }
      }
    });
  }

  void _initializeLocation() {
    const defaultLat = 12.9716;
    const defaultLng = 77.5946;

    _initialPosition = LatLng(
      widget.userLatitude ?? defaultLat,
      widget.userLongitude ?? defaultLng,
    );
    _selectedLocation = _initialPosition;
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    setState(() {
      _mapReady = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                    style: PoppinsFont.textStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                      style: PoppinsFont.textStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
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
                        return AppLocalizations.of(context)?.fullNameRequired ??
                            'Full name is required';
                      }
                      return null;
                    },
                    hint: Text(
                      AppLocalizations.of(context)?.fullName ?? 'Full Name',
                      style: PoppinsFont.textStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
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
                      style: PoppinsFont.textStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(
                              context,
                            )?.phoneNumberRequired ??
                            'Phone number is required';
                      }
                      if (kDebugMode) {
                        return null;
                      } else {
                        final saudiRegex = RegExp(
                          r'^(?:\+966|00966|0)?5[0-9]{8}$',
                        );
                        if (!saudiRegex.hasMatch(value)) {
                          return AppLocalizations.of(
                            context,
                          )!.phoneNumberInvalid;
                        }
                        return null;
                      }
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                      child: _isAddingAddress
                          ? Loader()
                          : Text(
                              AppLocalizations.of(context)?.saveAddress ??
                                  'Save Address',
                              style: PoppinsFont.textStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
          id: DateTime.now().millisecondsSinceEpoch.toString(),
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
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
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
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _predictions.length,
        itemBuilder: (context, index) {
          return ListTile(
            dense: true,
            title: Text(
              _predictions[index],
              style: const TextStyle(fontSize: 14),
            ),
            leading: const Icon(Icons.location_on, size: 20),
            onTap: () => _moveCameraToPlace(_predictions[index]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.chooseLocation ?? 'Choose Location',
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (!_mapReady)
                  const Center(child: CircularProgressIndicator()),
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
                  top: 15,
                  left: 15,
                  right: 15,
                  child: Column(
                    children: [
                      Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _searchPlaces,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(
                                  context,
                                )?.pickServiceAddress ??
                                'Pick service address',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
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
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSearchResults(),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 100,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _getCurrentLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location,
                              size: 16,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(
                                    context,
                                  )?.useMyCurrentLocation ??
                                  'Use my current location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.serviceto ?? 'Service to',
            style: PoppinsFont.textStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          LocationCard(
            title: _locationTitle.isNotEmpty
                ? _locationTitle
                : AppLocalizations.of(context)?.selectLocation ??
                      'Select Location',
            subtitle: _locationSubtitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.blue,
              ),
              onPressed: _selectedLocation != null
                  ? () => _showAddressDetailsBottomSheet()
                  : null,
              child: Text(
                AppLocalizations.of(context)?.addAddressDetails ??
                    'Add Address Details',
                style: PoppinsFont.textStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
