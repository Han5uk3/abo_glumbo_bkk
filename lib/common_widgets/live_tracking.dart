import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:abo_glumbo_bbk/apis/google_tracking_polylines.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/tracking_data.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveTrackingPage extends StatefulWidget {
  final BookingModel? booking;
  const LiveTrackingPage({super.key, required this.booking});
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
  final bool _useMockData = false;
  final LatLng _mockCustomerLocation = const LatLng(19.0760, 72.8777);
  final LatLng _mockAgentLocation = const LatLng(19.0896, 72.8656);
  final List<LatLng> _mockRoutePoints = [
    LatLng(19.0760, 72.8777),
    LatLng(19.0780, 72.8750),
    LatLng(19.0820, 72.8720),
    LatLng(19.0850, 72.8690),
    LatLng(19.0896, 72.8656),
  ];
  String? eta;
  String? distance;
  Timer? _etaDebounce;

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
    _etaDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLocationPermission) {
      _startLocationTracking();
    }
    if (state == AppLifecycleState.detached) {
      _stopLocationTracking();
    }
  }

  Future<void> _initializeTracking() async {
    try {
      await _setCustomMarkerIcons();
      if (_useMockData) {
        await _loadMockData();
        _setMockRoute();
        _scheduleMockMovement();
      } else {
        await _requestLocationPermission();
        if (_hasLocationPermission) {
          await _loadCustomerLocation();
          if (widget.booking?.agent?.uid != null) {
            _listenToAgentLocation();
          }
        }
      }
      await _fetchETAAndRoute();
    } catch (e) {
      _handleError('Failed to initialize tracking: $e');
    }
  }

  Future<void> _setCustomMarkerIcons() async {
    try {
      _scooterIcon = await _getResizedMarker('assets/images/scooter.png', 100);
      _customerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
    } catch (_) {
      _scooterIcon = BitmapDescriptor.defaultMarker;
      _customerIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<BitmapDescriptor> _getResizedMarker(
    String assetPath,
    int width,
  ) async {
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

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }
      _hasLocationPermission = true;
      _startLocationTracking();
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> _loadCustomerLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _customerLatLng = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      _handleError('Failed to get customer location: $e');
    }
  }

  void _startLocationTracking() {
    const settings = LocationSettings(accuracy: LocationAccuracy.high);
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
          setState(() {
            _customerLatLng = LatLng(pos.latitude, pos.longitude);
          });
          _scheduleFetchETA();
        }, onError: (e) => _handleError('Customer location stream error: $e'));
  }

  void _stopLocationTracking() => _locationSubscription?.cancel();

  void _listenToAgentLocation() {
    _agentLocationSubscription = AppServices()
        .getAgentLiveLocationStream(widget.booking?.agent?.uid ?? '')
        .listen((user) async {
          final liveLocation = user.liveLocation;
          final lat = liveLocation?.latitude;
          final lng = liveLocation?.longitude;
          if (lat != null && lng != null) {
            setState(() {
              _previousAgentLatLng = _agentLatLng;
              _agentLatLng = LatLng(lat, lng);
            });
            _scheduleFetchETA();
            if (_isFollowingAgent && _isMapReady) _moveCameraToBounds();
          }
        }, onError: (e) => _handleError('Agent location error: $e'));
  }

  void _scheduleFetchETA() {
    _etaDebounce?.cancel();
    _etaDebounce = Timer(const Duration(seconds: 5), () {
      _fetchETAAndRoute();
    });
  }

  Future<void> _fetchETAAndRoute() async {
    if (_agentLatLng == null || _customerLatLng == null) return;
    try {
      final result = await getEtaAndDistance(
        originLat: _agentLatLng!.latitude,
        originLng: _agentLatLng!.longitude,
        destinationLat: _customerLatLng!.latitude,
        destinationLng: _customerLatLng!.longitude,
        apiKey: 'AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o',
      );
      setState(() {
        eta = result['duration'];
        distance = result['distance'];
      });
      if (result['polyline'] != null) {
        final polylinePoints = PolylinePoints.decodePolyline(
          result['polyline'],
        );
        setState(() {
          routePoints = polylinePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        });
      }
      if ((distance == null || distance!.isEmpty) &&
          _agentLatLng != null &&
          _customerLatLng != null) {
        final d = _calculateStraightDistanceKm(_agentLatLng!, _customerLatLng!);
        setState(() {
          distance = "${d.toStringAsFixed(1)} km";
        });
      }
    } catch (e) {
      debugPrint("❌ ETA fetch error: $e");
      if (_agentLatLng != null && _customerLatLng != null) {
        final d = _calculateStraightDistanceKm(_agentLatLng!, _customerLatLng!);
        setState(() {
          distance = "${d.toStringAsFixed(1)} km";
          eta ??= '—';
        });
      }
    }
  }

  double _calculateStraightDistanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final hav =
        0.5 -
        math.cos((b.latitude - a.latitude) * p) / 2 +
        math.cos(a.latitude * p) *
            math.cos(b.latitude * p) *
            (1 - math.cos((b.longitude - a.longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(hav));
  }

  Future<void> _loadMockData() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _customerLatLng = _mockCustomerLocation;
      _agentLatLng = _mockAgentLocation;
      _isLoading = false;
      routePoints = _mockRoutePoints;
    });
  }

  void _setMockRoute() {
    setState(() {
      routePoints = _mockRoutePoints;
    });
  }

  void _scheduleMockMovement() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _agentLatLng == null) {
        timer.cancel();
        return;
      }
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
      _fetchETAAndRoute();
      if (_isFollowingAgent && _isMapReady) _moveCameraToBounds();
    });
  }

  void _moveCameraToBounds() {
    if (_agentLatLng != null &&
        _customerLatLng != null &&
        _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_agentLatLng!.latitude, _customerLatLng!.latitude),
          math.min(_agentLatLng!.longitude, _customerLatLng!.longitude),
        ),
        northeast: LatLng(
          math.max(_agentLatLng!.latitude, _customerLatLng!.latitude),
          math.max(_agentLatLng!.longitude, _customerLatLng!.longitude),
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _handleError(String error) {
    setState(() {
      _errorMessage = error;
      _isLoading = false;
    });
    debugPrint('❌ Error: $error');
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 48),
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

  Future<void> _applyMapStyle() async {
    if (_mapController != null) {
      final style = await rootBundle.loadString(
        'assets/map_styles/gray_map.json',
      );
      _mapController?.setMapStyle(style);
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
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _isMapReady = true;
                            _applyMapStyle();
                            if (_isFollowingAgent) _moveCameraToBounds();
                          },
                          initialCameraPosition: CameraPosition(
                            target: _customerLatLng ?? _mockCustomerLocation,
                            zoom: 14,
                          ),
                          trafficEnabled: _showTrafficLayer,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
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
                                color: const Color(0xFF006400),
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
                      worker: widget.booking?.agent,
                    ),
                  ],
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: SafeArea(
                    child: ClipOval(
                      child: Material(
                        color: Colors.white.withOpacity(0.9),
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
