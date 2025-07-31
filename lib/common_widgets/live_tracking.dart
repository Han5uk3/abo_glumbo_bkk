import 'dart:ui' as ui;
import 'package:abo_glumbo_bbk/apis/google_tracking_polylines.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/tracking_data.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;

class LiveTrackingPage extends StatefulWidget {
  // TODO: Uncomment these when you have actual data
  // final String bookingId;
  // final String agentId;

  const LiveTrackingPage({
    super.key,
    // TODO: Uncomment these when you have actual data
    // required this.bookingId,
    // required this.agentId,
  });

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  BitmapDescriptor? _scooterIcon;
  BitmapDescriptor? _customerIcon;

  LatLng? _customerLatLng;
  LatLng? _agentLatLng;
  LatLng? _previousAgentLatLng;

  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _agentLocationSubscription;

  bool _isLoading = true;
  bool _isMapReady = false;
  bool _hasLocationPermission = false;
  String? _errorMessage;

  bool _isFollowingAgent = true;
  bool _showTrafficLayer = false;
  List<LatLng> routePoints = [];
  final bool _useMockData = true;

  // TODO: Mock data for UI design - Remove when using real data
  final LatLng _mockCustomerLocation = const LatLng(19.0760, 72.8777); // Mumbai
  final LatLng _mockAgentLocation = const LatLng(
    19.0896,
    72.8656,
  ); // Bandra, Mumbai
  final List<LatLng> _mockRoutePoints = [
    LatLng(19.0760, 72.8777),
    LatLng(19.0780, 72.8750),
    LatLng(19.0820, 72.8720),
    LatLng(19.0850, 72.8690),
    LatLng(19.0896, 72.8656),
  ];
  int counter = 0;
  // NEW
  String? eta;

  String? distance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _agentLocationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_hasLocationPermission) _startLocationTracking();
        break;
      case AppLifecycleState.detached:
        _stopLocationTracking();
        break;
      default:
        break;
    }
  }

  Future<void> getPolylinePath() async {
    // TODO: Uncomment for real implementation
    // if (_agentLatLng != null && _customerLatLng != null) {
    //   try {
    //     final points = await getPolylinePointsFromGoogle(
    //       _agentLatLng!,
    //       _customerLatLng!,
    //     );
    //     if (points.isNotEmpty) {
    //       setState(() => routePoints = points);
    //     } else {
    //       debugPrint('⚠️ No polyline points received');
    //     }
    //   } catch (e) {
    //     debugPrint('❌ Error fetching polyline: $e');
    //   }
    // }

    // Mock implementation for UI design
    setState(() => routePoints = _mockRoutePoints);
  }

  Future<void> _initializeTracking() async {
    try {
      await _setCustomMarkerIcons();
      if (_useMockData) {
        await _loadMockData();
        getPolylinePath();
        fetchETA();
      } else {
        await _requestLocationPermission();
        if (_hasLocationPermission) {
          await _loadCustomerLocation();
          _listenToAgentLocation();
          getPolylinePath();
          fetchETA();
        }
      }
    } catch (e) {
      _handleError('Failed to initialize tracking: $e');
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, color: Colors.red, size: 48),
          const SizedBox(height: 10),
          Text(_errorMessage ?? "Unknown error", textAlign: TextAlign.center),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _initializeTracking,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  // TODO: Mock method for UI design - Remove when using real data
  Future<void> _loadMockData() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate loading
    setState(() {
      _customerLatLng = _mockCustomerLocation;
      _agentLatLng = _mockAgentLocation;
      _isLoading = false;
    });

    // Simulate agent movement for UI testing
    _simulateAgentMovement();
  }

  // TODO: Mock method for UI design - Remove when using real data
  void _simulateAgentMovement() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _agentLatLng != null) {
        // Simulate small movements
        final random = math.Random();
        final latOffset = (random.nextDouble() - 0.5) * 0.001;
        final lngOffset = (random.nextDouble() - 0.5) * 0.001;

        setState(() {
          _previousAgentLatLng = _agentLatLng;
          _agentLatLng = LatLng(
            _agentLatLng!.latitude + latOffset,
            _agentLatLng!.longitude + lngOffset,
          );
        });
        fetchETA();
        if (_isFollowingAgent && _isMapReady) _moveCameraToBounds();
      }
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }
      _hasLocationPermission = true;
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<Position> _getCurrentLocation() async =>
      await Geolocator.getCurrentPosition();

  void _startLocationTracking() {
    // TODO: Uncomment for real implementation
    // const settings = LocationSettings(accuracy: LocationAccuracy.high);
    // _locationSubscription =
    //     Geolocator.getPositionStream(locationSettings: settings).listen(
    //       (pos) => setState(
    //         () => _customerLatLng = LatLng(pos.latitude, pos.longitude),
    //       ),
    //       onError: (e) => _handleError('Location stream error: $e'),
    //     );
  }

  void _stopLocationTracking() => _locationSubscription?.cancel();

  Future<BitmapDescriptor> getResizedMarker(String assetPath, int width) async {
    final ByteData data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? resizedData = await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(resizedData!.buffer.asUint8List());
  }

  Future<void> _setCustomMarkerIcons() async {
    try {
      _scooterIcon = await getResizedMarker('assets/images/scooter.png', 200);
      _customerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
    } catch (_) {
      _scooterIcon = BitmapDescriptor.defaultMarker;
      _customerIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _loadCustomerLocation() async {
    try {
      final position = await _getCurrentLocation();
      setState(() {
        _customerLatLng = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _startLocationTracking();
    } catch (e) {
      _handleError('Failed to get your location: $e');
    }
  }

  void _listenToAgentLocation() {
    // TODO: Uncomment for real implementation
    // _agentLocationSubscription = AppServices()
    //     .getAgentLiveLocationStream(widget.agentId)
    //     .listen((user) async {
    //       final liveLocation = user.liveLocation;
    //       final lat = liveLocation?.latitude;
    //       final lng = liveLocation?.longitude;
    //       if (lat != null && lng != null) {
    //         setState(() {
    //           _previousAgentLatLng = _agentLatLng;
    //           _agentLatLng = LatLng(lat, lng);
    //         });
    //         await getPolylinePath();
    //         if (_isFollowingAgent && _isMapReady) _moveCameraToBounds();
    //       }
    //     }, onError: (e) => _handleError('Agent location error: $e'));
  }

  void _moveCameraToBounds() {
    if (_agentLatLng != null &&
        _customerLatLng != null &&
        _mapController != null) {
      LatLngBounds bounds = _calculateBounds(_agentLatLng!, _customerLatLng!);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  LatLngBounds _calculateBounds(LatLng p1, LatLng p2) {
    return LatLngBounds(
      southwest: LatLng(
        math.min(p1.latitude, p2.latitude),
        math.min(p1.longitude, p2.longitude),
      ),
      northeast: LatLng(
        math.max(p1.latitude, p2.latitude),
        math.max(p1.longitude, p2.longitude),
      ),
    );
  }

  void _handleError(String error) {
    setState(() {
      _errorMessage = error;
      _isLoading = false;
    });
    debugPrint('❌ Error: $error');
  }

  // NEW
  void fetchETA() async {
    if (_agentLatLng == null || _customerLatLng == null) return;

    try {
      final result = await getEtaAndDistance(
        originLat: _agentLatLng!.latitude,
        originLng: _agentLatLng!.longitude,
        destinationLat: _customerLatLng!.latitude,
        destinationLng: _customerLatLng!.longitude,
        apiKey: "AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o",
      );

      setState(() {
        eta = result['duration'];
        distance = result['distance'];
      });

      if (!_useMockData && result['polyline'] != null) {
        final polylinePoints = PolylinePoints.decodePolyline(
          result['polyline'],
        );
        setState(() {
          routePoints = polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("❌ ETA fetch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading || _scooterIcon == null || _customerIcon == null
          ? Center(child: Loader(color: AppColors.primary))
          : _errorMessage != null
          ? _buildErrorWidget()
          : Stack(
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GoogleMap(
                          onMapCreated: (controller) async {
                            _mapController = controller;
                            _isMapReady = true;

                            final style = await rootBundle.loadString(
                              'assets/map_styles/gray_map.json',
                            );
                            _mapController?.setMapStyle(style);

                            if (_isFollowingAgent) _moveCameraToBounds();
                          },
                          initialCameraPosition: CameraPosition(
                            target: _customerLatLng ?? _mockCustomerLocation,
                            zoom: 14,
                          ),
                          trafficEnabled: _showTrafficLayer,
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          compassEnabled: false,
                          markers: {
                            if (_customerLatLng != null)
                              Marker(
                                markerId: const MarkerId('customer'),
                                position: _customerLatLng!,
                                icon: _customerIcon!,
                                infoWindow: const InfoWindow(
                                  title: 'You are here',
                                ),
                              ),
                            if (_agentLatLng != null)
                              Marker(
                                markerId: const MarkerId('agent'),
                                position: _agentLatLng!,
                                icon: _scooterIcon!,
                                infoWindow: const InfoWindow(
                                  title: 'Agent Location',
                                ),
                              ),
                          },
                          polylines: {
                            if (routePoints.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId("route"),
                                color: AppColors
                                    .primary, // Or Colors.green[800] for dark green
                                width:
                                    MediaQuery.of(context).devicePixelRatio < 2
                                    ? 4
                                    : 5,
                                startCap: Cap.roundCap,
                                endCap: Cap.roundCap,
                                jointType: JointType.round,
                                points: routePoints,
                              ),
                          },
                        ),
                      ),
                    ),
                    TrackingData(
                      timeTakenToArrive: eta ?? 'Loading...',
                      remainingKm: distance ?? 'Loading...',
                    ),
                  ],
                ),

                // Top-left pop button
                Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(
                    child: ClipOval(
                      child: Material(
                        color: Colors.white.withOpacity(
                          0.9,
                        ), // Optional background
                        child: InkWell(
                          splashColor: Colors.grey[300],
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_back, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
