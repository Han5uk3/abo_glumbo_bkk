import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:abo_glumbo_bbk/apis/google_tracking_polylines.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/tracking_data.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTrackingPage extends StatefulWidget {
  final BookingModel? booking;
  final AddressModel selectedAddress;
  const LiveTrackingPage({
    super.key,
    required this.booking,
    required this.selectedAddress,
  });
  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  BitmapDescriptor? _scooterIcon;
  BitmapDescriptor? _customerIcon;

  LatLng? _customerLatLng; // Static - from selectedAddress
  LatLng? _agentLatLng; // Dynamic - from live tracking
  LatLng? _previousAgentLatLng;

  StreamSubscription? _agentLocationSubscription;

  bool _isLoading = true;
  bool _isMapReady = false;
  String? _errorMessage;
  bool _isFollowingAgent = true;
  final bool _showTrafficLayer = false;
  List<LatLng> routePoints = [];
  String? eta;
  String? distance;
  Timer? _etaDebounce;
  Timer? _cameraDebounce;

  // Mock data for testing
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

  static const Duration _markerAnimationDuration = Duration(milliseconds: 500);
  static const int _markerFrames = 30;
  Timer? _agentMarkerAnimTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _agentLocationSubscription?.cancel();
    _etaDebounce?.cancel();
    _cameraDebounce?.cancel();
    _mapController?.dispose();
    _agentMarkerAnimTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Since customer location is static, no need to handle app lifecycle changes
    // Agent location continues to be tracked through the stream
  }

  Future<void> _initializeTracking() async {
    try {
      await _setCustomMarkerIcons();
      if (_useMockData) {
        await _loadMockData();
        _setMockRoute();
        _scheduleMockMovement();
      } else {
        // Load static customer location from selectedAddress
        await _loadCustomerLocation();

        // Start tracking agent location
        final agentUid = widget.booking?.agent?.uid;
        if (agentUid != null && agentUid.isNotEmpty) {
          _listenToAgentLocation(agentUid);
        } else {
          debugPrint('⚠️ No agent UID found in booking');
        }
      }
      await _fetchETAAndRoute();
    } catch (e) {
      _handleError('Failed to initialize tracking: $e');
    }
  }

  Future<void> _setCustomMarkerIcons() async {
    try {
      _scooterIcon = await _getResizedMarker('assets/images/scooter.png', 200);
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

  Future<void> _loadCustomerLocation() async {
    try {
      final lat = widget.selectedAddress.lat ?? 0.0;
      final lon = widget.selectedAddress.lon ?? 0.0;

      debugPrint('🏠 [CUSTOMER] Static coordinates from selectedAddress:');
      debugPrint('🏠 [CUSTOMER]   Latitude: $lat');
      debugPrint('🏠 [CUSTOMER]   Longitude: $lon');
      debugPrint('🏠 [CUSTOMER]   Address: ${widget.selectedAddress.streetName}');

      // Validate coordinates
      if (lat == 0.0 && lon == 0.0) {
        throw Exception('Invalid customer address coordinates');
      }

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        throw Exception('Customer address coordinates out of valid range');
      }

      final customerPosition = LatLng(lat, lon);

      setState(() {
        _customerLatLng = customerPosition;
        _isLoading = false;
        if (_agentLatLng != null) {
          _moveCameraToBounds(
            customerLatLng: _customerLatLng!,
            agentLatLng: _agentLatLng!,
          );
        }
      });
      debugPrint('📍 Customer Delivery Address SET (STATIC): $lat, $lon');
    } catch (e) {
      _handleError('Failed to load customer address: $e');
    }
  }

  void _listenToAgentLocation(String agentUid) {
    _agentLocationSubscription?.cancel();
    _agentLocationSubscription = AppServices()
        .getAgentLiveLocationStream(agentUid)
        .listen((user) async {
          final liveLocation = user.liveLocation;
          final lat = liveLocation?.latitude;
          final lng = liveLocation?.longitude;
          if (lat != null && lng != null) {
            final newAgentLatLng = LatLng(lat, lng);

            debugPrint(
              '🚗 [AGENT] Location update: ${newAgentLatLng.latitude}, ${newAgentLatLng.longitude} at ${DateTime.now()}',
            );
            debugPrint('🚗 [AGENT] Delivery address: $_customerLatLng');

            // Schedule ETA recalculation when agent location changes
            _scheduleFetchETA();

            // Update agent location if it has changed
            if (_agentLatLng == null ||
                _agentLatLng!.latitude != newAgentLatLng.latitude ||
                _agentLatLng!.longitude != newAgentLatLng.longitude) {
              // Animate agent marker to new location
              _animateAgentMarker(newAgentLatLng);

              // Update camera to show both locations if following mode is enabled
              if (_customerLatLng != null &&
                  _mapController != null &&
                  _isFollowingAgent) {
                _debouncedCameraUpdate();
              }
            }
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
    if (_agentLatLng == null || _customerLatLng == null) {
      debugPrint('[LOG] Cannot fetch ETA: Missing coordinates');
      debugPrint('[LOG] Agent: $_agentLatLng, Customer: $_customerLatLng');
      return;
    }

    final distanceBetween = _calculateStraightDistanceKm(
      _agentLatLng!,
      _customerLatLng!,
    );
    debugPrint(
      '[LOG] Fetching ETA for distance: ${distanceBetween.toStringAsFixed(2)} km',
    );
    debugPrint(
      '[LOG] Agent coordinates: ${_agentLatLng!.latitude}, ${_agentLatLng!.longitude}',
    );
    debugPrint(
      '[LOG] Delivery address: ${_customerLatLng!.latitude}, ${_customerLatLng!.longitude}',
    );

    try {
      final result = await getEtaAndDistance(
        originLat: _agentLatLng!.latitude,
        originLng: _agentLatLng!.longitude,
        destinationLat: _customerLatLng!.latitude,
        destinationLng: _customerLatLng!.longitude,
        apiKey: 'AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o',
      );

      String? newEta;
      String? newDistance;
      List<LatLng> newRoute = [];

      if (result is Map) {
        newEta = result['duration'] as String?;
        newDistance = result['distance'] as String?;
        final polyline = result['polyline'] as String?;

        debugPrint('[LOG] API Result - ETA: $newEta, Distance: $newDistance');
        debugPrint(
          '[LOG] Polyline received: ${polyline?.isNotEmpty == true ? "Yes (${polyline!.length} chars)" : "No"}',
        );

        if (polyline != null && polyline.isNotEmpty) {
          try {
            final points = PolylinePoints.decodePolyline(polyline);
            newRoute = points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
            debugPrint('[LOG] Decoded ${newRoute.length} route points');
          } catch (e) {
            debugPrint('[LOG] Failed to decode polyline: $e');
          }
        }
      } else {
        debugPrint('[LOG] API result is not a Map: $result');
      }

      // Fallback for distance calculation
      if ((newDistance == null || newDistance.isEmpty)) {
        final d = _calculateStraightDistanceKm(_agentLatLng!, _customerLatLng!);
        newDistance = "${d.toStringAsFixed(1)} km";
        debugPrint('[LOG] Using fallback distance: $newDistance');
      }

      setState(() {
        eta = newEta ?? eta;
        distance = newDistance ?? distance;
        if (newRoute.isNotEmpty) {
          routePoints = newRoute;
          debugPrint(
            '[LOG] Route points updated: ${routePoints.length} points',
          );
        } else {
          // If no route from API, create a simple straight line
          routePoints = [_agentLatLng!, _customerLatLng!];
          debugPrint('[LOG] Using fallback straight line route');
        }
      });

      // Update camera to show both locations with the new route
      if (_isFollowingAgent && _mapController != null) {
        _moveCameraToBounds(
          customerLatLng: _customerLatLng!,
          agentLatLng: _agentLatLng!,
        );
      }
    } catch (e) {
      debugPrint("❌ ETA fetch error: $e");
      final d = _calculateStraightDistanceKm(_agentLatLng!, _customerLatLng!);
      setState(() {
        distance = "${d.toStringAsFixed(1)} km";
        eta ??= '—';
        // Create fallback route
        routePoints = [_agentLatLng!, _customerLatLng!];
        debugPrint(
          '[LOG] Created fallback route with ${routePoints.length} points',
        );
      });

      // Update camera to show both locations
      if (_isFollowingAgent && _mapController != null) {
        _moveCameraToBounds(
          customerLatLng: _customerLatLng!,
          agentLatLng: _agentLatLng!,
        );
      }
    }
  }

  double _calculateStraightDistanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295; // π/180
    final dlat = (b.latitude - a.latitude) * p;
    final dlon = (b.longitude - a.longitude) * p;
    final lat1 = a.latitude * p;
    final lat2 = b.latitude * p;

    final hav =
        math.pow(math.sin(dlat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
    final distance = 12742 * math.asin(math.sqrt(hav)); // 2 * R * asin(...)

    debugPrint('[DISTANCE] 🧮 Calculation Details:');
    debugPrint('[DISTANCE]   Agent: ${a.latitude}, ${a.longitude}');
    debugPrint('[DISTANCE]   Delivery Address: ${b.latitude}, ${b.longitude}');
    debugPrint(
      '[DISTANCE]   Are coordinates identical? ${a.latitude == b.latitude && a.longitude == b.longitude}',
    );
    debugPrint(
      '[DISTANCE]   Final distance: ${distance.toStringAsFixed(6)} km',
    );

    return distance;
  }

  double _getInitialZoom() {
    if (_agentLatLng == null || _customerLatLng == null) {
      return 16.0; // Default zoom for single location
    }

    final distanceBetween = _calculateStraightDistanceKm(
      _customerLatLng!,
      _agentLatLng!,
    );

    if (distanceBetween > 500) {
      return 5.0; // Continental view
    } else if (distanceBetween > 100) {
      return 7.0; // Country view
    } else if (distanceBetween > 50) {
      return 9.0; // Region view
    } else if (distanceBetween > 15) {
      return 11.0; // City view
    } else if (distanceBetween > 5) {
      return 13.0; // Local area view
    } else {
      return 14.0; // Neighborhood view
    }
  }

  Future<void> _loadMockData() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _customerLatLng = _mockCustomerLocation;
      _agentLatLng = _mockAgentLocation;
      _previousAgentLatLng = _agentLatLng;
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
      final newAgent = LatLng(
        _agentLatLng!.latitude + latOffset,
        _agentLatLng!.longitude + lngOffset,
      );
      _animateAgentMarker(newAgent);
      _fetchETAAndRoute();
      if (_isFollowingAgent && _isMapReady) _debouncedCameraUpdate();
    });
  }

  void _debouncedCameraUpdate() {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_customerLatLng != null && _agentLatLng != null) {
        _moveCameraToBounds(
          customerLatLng: _customerLatLng!,
          agentLatLng: _agentLatLng!,
        );
      }
    });
  }

  void _moveCameraToBounds({
    required LatLng customerLatLng,
    required LatLng agentLatLng,
  }) async {
    log("[LOG] _moveCameraToBounds() called");

    if (_mapController == null) return;

    // Calculate distance between the two points
    final distanceBetween = _calculateStraightDistanceKm(
      customerLatLng,
      agentLatLng,
    );

    log(
      '[LOG] Distance between delivery address and agent: ${distanceBetween.toStringAsFixed(2)} km',
    );
    log(
      '[LOG] Delivery Address: ${customerLatLng.latitude}, ${customerLatLng.longitude}',
    );
    log('[LOG] Agent: ${agentLatLng.latitude}, ${agentLatLng.longitude}');

    try {
      // For very long distances, use bounds-based approach
      if (distanceBetween > 50.0) {
        final swLat = math.min(customerLatLng.latitude, agentLatLng.latitude);
        final swLng = math.min(customerLatLng.longitude, agentLatLng.longitude);
        final neLat = math.max(customerLatLng.latitude, agentLatLng.latitude);
        final neLng = math.max(customerLatLng.longitude, agentLatLng.longitude);

        // Add some padding to the bounds
        final latPadding = (neLat - swLat) * 0.1; // 10% padding
        final lngPadding = (neLng - swLng) * 0.1; // 10% padding

        final bounds = LatLngBounds(
          southwest: LatLng(swLat - latPadding, swLng - lngPadding),
          northeast: LatLng(neLat + latPadding, neLng + lngPadding),
        );

        log('[LOG] Using bounds approach for long distance');

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      } else {
        // For shorter distances, use center-based approach with smart zoom
        final centerLat = (customerLatLng.latitude + agentLatLng.latitude) / 2;
        final centerLng =
            (customerLatLng.longitude + agentLatLng.longitude) / 2;
        final center = LatLng(centerLat, centerLng);

        // Adjust zoom level based on distance
        double zoom;
        if (distanceBetween < 0.5) {
          zoom = 17.0; // Very close
        } else if (distanceBetween < 1.0) {
          zoom = 16.0; // Close
        } else if (distanceBetween < 3.0) {
          zoom = 15.0; // Medium
        } else if (distanceBetween < 8.0) {
          zoom = 13.0; // City distance
        } else if (distanceBetween < 15.0) {
          zoom = 12.0; // Regional
        } else if (distanceBetween < 25.0) {
          zoom = 11.0; // Very far
        } else {
          zoom = 10.0; // Extremely far
        }

        log('[LOG] Using center approach with zoom: $zoom');

        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: center, zoom: zoom),
          ),
        );
      }
    } catch (e) {
      log('[LOG] Failed to animate camera: $e');
    }

    log('[LOG] Camera animation completed');
  }

  void _animateAgentMarker(LatLng newLoc) {
    _agentMarkerAnimTimer?.cancel();

    if (_agentLatLng == null) {
      setState(() {
        _agentLatLng = newLoc;
        _previousAgentLatLng = newLoc;
      });
      return;
    }

    final start = _agentLatLng!;
    int current = 0;
    final frameInterval = _markerAnimationDuration ~/ _markerFrames;

    _agentMarkerAnimTimer = Timer.periodic(frameInterval, (timer) {
      current++;
      final t = (current / _markerFrames).clamp(0.0, 1.0);
      final lat = start.latitude + (newLoc.latitude - start.latitude) * t;
      final lng = start.longitude + (newLoc.longitude - start.longitude) * t;
      setState(() {
        _agentLatLng = LatLng(lat, lng);
      });
      if (current >= _markerFrames) {
        timer.cancel();
        _previousAgentLatLng = newLoc;
        _agentMarkerAnimTimer = null;
      }
    });
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
      try {
        final style = await rootBundle.loadString(
          'assets/map_styles/gray_map.json',
        );
        _mapController?.setMapStyle(style);
      } catch (e) {
        debugPrint("⚠️ Failed to apply map style: $e");
      }
    }
  }

  Future<void> openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (!await launchUrl(uri)) {
      debugPrint('Could not open settings');
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
                            _controller.complete(controller);
                            _isMapReady = true;
                            _applyMapStyle();
                            if (_customerLatLng != null &&
                                _agentLatLng != null) {
                              _moveCameraToBounds(
                                customerLatLng: _customerLatLng!,
                                agentLatLng: _agentLatLng!,
                              );
                            }
                          },
                          initialCameraPosition: CameraPosition(
                            target: _customerLatLng ?? _mockCustomerLocation,
                            zoom: _getInitialZoom(),
                          ),
                          trafficEnabled: _showTrafficLayer,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          compassEnabled: false,
                          markers: {
                            // Static delivery address marker
                            if (_customerLatLng != null)
                              Marker(
                                markerId: const MarkerId('customer'),
                                position: _customerLatLng!,
                                icon: _customerIcon!,
                                // infoWindow: InfoWindow(
                                //   title: 'Delivery Address',
                                //   snippet:
                                //       widget.selectedAddress.address ??
                                //       'Delivery location',
                                // ),
                              ),
                            // Dynamic agent location marker
                            if (_agentLatLng != null)
                              Marker(
                                markerId: const MarkerId('agent'),
                                position: _agentLatLng!,
                                icon: _scooterIcon!,
                                infoWindow: InfoWindow(
                                  title:
                                      widget.booking?.agent?.name ??
                                      'Delivery Agent',
                                  snippet: 'Live location',
                                ),
                              ),
                          },
                          polylines: {
                            if (routePoints.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId("route"),
                                color: const Color(
                                  0xFF1976D2,
                                ), // Darker blue for better visibility
                                width:
                                    MediaQuery.of(context).devicePixelRatio < 2
                                    ? 5
                                    : 6,
                                startCap: Cap.roundCap,
                                endCap: Cap.roundCap,
                                jointType: JointType.round,
                                points: routePoints,
                                patterns: routePoints.length == 2
                                    ? [
                                        PatternItem.dash(20),
                                        PatternItem.gap(10),
                                      ] // Dashed line for straight route
                                    : [], // Solid line for API route
                              ),
                          },
                        ),
                      ),
                    ),
                    TrackingData(
                      timeTakenToArrive:
                          eta ??
                          (_agentLatLng == null
                              ? AppLocalizations.of(
                                  context,
                                )!.waitingForAgentLocation
                              : AppLocalizations.of(context)!.calculating),
                      remainingKm:
                          distance ??
                          (_agentLatLng == null
                              ? '--'
                              : AppLocalizations.of(context)!.calculating),
                      worker: widget.booking?.agent,
                    ),
                  ],
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: Directionality.of(context) == TextDirection.rtl
                      ? null
                      : 8,
                  right: Directionality.of(context) == TextDirection.rtl
                      ? 8
                      : null,
                  child: SafeArea(
                    child: ClipOval(
                      child: Material(
                        color: Colors.white.withOpacity(0.9),
                        child: InkWell(
                          splashColor: Colors.grey[300],
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_back, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Toggle view button
                // if (_customerLatLng != null && _agentLatLng != null)
                //   Positioned(
                //     bottom: 100,
                //     right: 16,
                //     child: Tooltip(
                //       message: _isFollowingAgent
                //           ? 'Focus on Delivery Address'
                //           : 'Show Both Locations',
                //       child: FloatingActionButton(
                //         mini: true,
                //         backgroundColor: Colors.white,
                //         onPressed: () {
                //           setState(() {
                //             _isFollowingAgent = !_isFollowingAgent;
                //           });

                //           if (_isFollowingAgent) {
                //             // Show both markers
                //             _moveCameraToBounds(
                //               customerLatLng: _customerLatLng!,
                //               agentLatLng: _agentLatLng!,
                //             );
                //           } else {
                //             // Focus on delivery address
                //             _mapController?.animateCamera(
                //               CameraUpdate.newCameraPosition(
                //                 CameraPosition(
                //                   target: _customerLatLng!,
                //                   zoom: 16.0,
                //                 ),
                //               ),
                //             );
                //           }
                //         },
                //         child: Icon(
                //           _isFollowingAgent
                //               ? Icons.location_on
                //               : Icons.zoom_out_map,
                //           color: Colors.blue,
                //           size: 20,
                //         ),
                //       ),
                //     ),
                //   ),
              ],
            ),
    );
  }
}
