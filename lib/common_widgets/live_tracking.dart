import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:abo_glumbo_bbk/configs/env_config.dart';
import 'package:abo_glumbo_bbk/apis/google_tracking_polylines.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/tracking_data.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
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

  LatLng? _customerLatLng;
  LatLng? _agentLatLng;
  LatLng? _previousAgentLatLng;

  StreamSubscription? _agentLocationSubscription;

  bool _isLoading = true;
  bool _isMapReady = false;
  String? _errorMessage;
  // ignore: prefer_final_fields
  bool _isFollowingAgent = true;
  final bool _showTrafficLayer = false;
  List<LatLng> routePoints = [];
  String? eta;
  String? distance;
  Timer? _etaDebounce;
  Timer? _cameraDebounce;

  // Track last ETA/distance update timestamp for cache validation
  int? _lastETAUpdateTimestamp;
  String? _lastTrackedAgentUid;
  static const Duration _etaDataValidityWindow = Duration(minutes: 5);

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
    // Capture initial delivery address to detect changes on multi-device scenarios
    _lastTrackedAgentUid = widget.booking?.agent?.uid;
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
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _initializeTracking() async {
    try {
      await _setCustomMarkerIcons();
      if (_useMockData) {
        await _loadMockData();
        _setMockRoute();
        _scheduleMockMovement();
      } else {
        await _loadCustomerLocation();

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
      debugPrint(
        '🏠 [CUSTOMER]   Address: ${widget.selectedAddress.streetName}',
      );

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

  /// Validate that ETA/distance data is still relevant for current booking
  bool _isETADataStillValid(String agentUid) {
    // Check if agent UID has changed (different agent assigned)
    if (_lastTrackedAgentUid != null && _lastTrackedAgentUid != agentUid) {
      debugPrint(
        '[ETA_VALIDATION] Agent UID changed from $_lastTrackedAgentUid to $agentUid - clearing cache',
      );
      return false;
    }

    // Check if data is too old
    if (_lastETAUpdateTimestamp != null) {
      final dataAge =
          DateTime.now().millisecondsSinceEpoch - _lastETAUpdateTimestamp!;
      if (dataAge > _etaDataValidityWindow.inMilliseconds) {
        debugPrint(
          '[ETA_VALIDATION] ETA data expired (age: ${dataAge}ms) - forcing refresh',
        );
        return false;
      }
    }

    return true;
  }

  void _listenToAgentLocation(String agentUid) {
    _agentLocationSubscription?.cancel();

    // Track current agent UID for multi-device safety
    _lastTrackedAgentUid = agentUid;
    debugPrint('[MULTI_DEVICE] Now tracking agent: $agentUid');

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

            _scheduleFetchETA();

            if (_agentLatLng == null ||
                _agentLatLng!.latitude != newAgentLatLng.latitude ||
                _agentLatLng!.longitude != newAgentLatLng.longitude) {
              _animateAgentMarker(newAgentLatLng);

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

    // Validate agent UID hasn't changed (multi-device safety check)
    final currentAgentUid = widget.booking?.agent?.uid;
    if (currentAgentUid != null && !_isETADataStillValid(currentAgentUid)) {
      debugPrint('[LOG] ETA data invalid - agent or booking may have changed');
      // Reset eta and distance to force fresh calculation
      setState(() {
        eta = null;
        distance = null;
      });
    }

    try {
      final result = await getEtaAndDistance(
        originLat: _agentLatLng!.latitude,
        originLng: _agentLatLng!.longitude,
        destinationLat: _customerLatLng!.latitude,
        destinationLng: _customerLatLng!.longitude,
        apiKey: EnvConfig.googleMapsApiKey,
      );

      String? newEta;
      String? newDistance;
      List<LatLng> newRoute = [];

      if (result is Map) {
        newEta = result['duration'] as String?;
        newDistance = result['distance'] as String?;

        final steps = result['steps'] as List?;
        if (steps != null && steps.isNotEmpty) {
          final List<LatLng> stitchedPoints = [];
          for (var step in steps) {
            final poly = step['polyline']?['points'] as String?;
            if (poly != null) {
              final decodedPoints = PolylinePoints.decodePolyline(poly);
              stitchedPoints.addAll(
                decodedPoints.map((p) => LatLng(p.latitude, p.longitude)),
              );
            }
          }
          newRoute = stitchedPoints;
          debugPrint(
            '[LOG] Stitched ${newRoute.length} high-res points from steps',
          );
        } else {
          // Fallback to overview if steps missing
          final polyline = result['overview_polyline'] as String?;
          if (polyline != null && polyline.isNotEmpty) {
            final points = PolylinePoints.decodePolyline(polyline);
            newRoute = points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
          }
        }

        debugPrint('[LOG] API Result - ETA: $newEta, Distance: $newDistance');
      } else {
        debugPrint('[LOG] API result is not a Map: $result');
      }

      if (newEta != null && newEta.isNotEmpty) {
        final etaMinutes = NotificationServices.extractMinutesFromDuration(
          newEta,
        );
        final bookingId = widget.booking?.id;
        final technicianName = widget.booking?.agent?.name ?? 'Technician';

        if (bookingId != null) {
          if (etaMinutes == 10) {
            if (!NotificationServices.hasTriggeredLocalNotification(
              bookingId,
              '10_minutes',
            )) {
              NotificationServices.showLocalLiveTrackingNotification(
                type: '10_minutes',
                bookingId: bookingId,
                technicianName: technicianName,
              );
              NotificationServices.markLocalNotificationTriggered(
                bookingId,
                '10_minutes',
              );
            }
          } else if (etaMinutes < 5 && etaMinutes >= 0) {
            if (!NotificationServices.hasTriggeredLocalNotification(
              bookingId,
              'nearby',
            )) {
              NotificationServices.showLocalLiveTrackingNotification(
                type: 'nearby',
                bookingId: bookingId,
                technicianName: technicianName,
              );
              NotificationServices.markLocalNotificationTriggered(
                bookingId,
                'nearby',
              );
            }
          }
        }
      }

      if ((newDistance == null || newDistance.isEmpty)) {
        final d = _calculateStraightDistanceKm(_agentLatLng!, _customerLatLng!);
        newDistance = "${d.toStringAsFixed(1)} km";
        debugPrint('[LOG] Using fallback distance: $newDistance');
      }

      final double straightDist = _calculateStraightDistanceKm(
        _agentLatLng!,
        _customerLatLng!,
      );
      final bool isPaused = widget.booking?.isTrackingPaused ?? false;

      setState(() {
        if (isPaused) {
          eta = '⏸️';
          distance = AppLocalizations.of(context)?.localeName == 'ar'
              ? 'تم إيقاف التتبع مؤقتًا'
              : 'Tracking Paused';
        } else if (straightDist > 100.0) {
          eta = '⚠️';
          distance = AppLocalizations.of(context)?.tooFarAway ?? 'Too far away';
        } else if (straightDist < 0.05) {
          eta = '0 mins';
          distance = AppLocalizations.of(context)?.localeName == 'ar'
              ? _convertDistanceToArabic('0.0 km')
              : '0.0 km away';
        } else {
          eta = newEta != null ? _convertTimeToArabic(newEta) : eta;
          if (newDistance != null) {
            distance = AppLocalizations.of(context)?.localeName == 'ar'
                ? _convertDistanceToArabic(newDistance)
                : '$newDistance away';
          }
        }

        if (newRoute.isNotEmpty) {
          routePoints = newRoute;
          debugPrint(
            '[LOG] Route points updated: ${routePoints.length} points',
          );
        } else {
          routePoints = [_agentLatLng!, _customerLatLng!];
          debugPrint('[LOG] Using fallback straight line route');
        }

        // Update tracking metadata for multi-device safety
        _lastETAUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
        _lastTrackedAgentUid = widget.booking?.agent?.uid;
      });

      if (_isFollowingAgent && _mapController != null) {
        _moveCameraToBounds(
          customerLatLng: _customerLatLng!,
          agentLatLng: _agentLatLng!,
        );
      }
    } catch (e) {
      debugPrint("❌ ETA fetch error: $e");
      final d = _calculateStraightDistanceKm(_agentLatLng!, _customerLatLng!);
      final bool isPaused = widget.booking?.isTrackingPaused ?? false;

      setState(() {
        if (isPaused) {
          eta = '⏸️';
          distance = AppLocalizations.of(context)?.localeName == 'ar'
              ? 'تم إيقاف التتبع مؤقتًا'
              : 'Tracking Paused';
        } else if (d > 100.0) {
          eta = '⚠️';
          distance = AppLocalizations.of(context)?.tooFarAway ?? 'Too far away';
        } else if (d < 0.05) {
          eta = '0 mins';
          distance = AppLocalizations.of(context)?.localeName == 'ar'
              ? _convertDistanceToArabic('0.0 km')
              : '0.0 km away';
        } else {
          distance = AppLocalizations.of(context)?.localeName == 'ar'
              ? _convertDistanceToArabic("${d.toStringAsFixed(1)} km")
              : "${d.toStringAsFixed(1)} km away";
          eta ??= '—';
        }

        routePoints = [_agentLatLng!, _customerLatLng!];
        debugPrint(
          '[LOG] Created fallback route with ${routePoints.length} points',
        );

        // Update tracking metadata for multi-device safety
        _lastETAUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
        _lastTrackedAgentUid = widget.booking?.agent?.uid;
      });

      if (_isFollowingAgent && _mapController != null) {
        _moveCameraToBounds(
          customerLatLng: _customerLatLng!,
          agentLatLng: _agentLatLng!,
        );
      }
    }
  }

  String _convertTimeToArabic(String? englishTime) {
    if (englishTime == null || englishTime.isEmpty) {
      return '';
    }

    if (AppLocalizations.of(context)!.localeName != 'ar') {
      return englishTime;
    }

    const englishToArabicNums = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };

    String arabicTime = englishTime;

    englishToArabicNums.forEach((english, arabic) {
      arabicTime = arabicTime.replaceAll(english, arabic);
    });

    arabicTime = arabicTime.replaceAll(' mins', ' دقيقة');
    arabicTime = arabicTime.replaceAll(' min', ' دقيقة');
    arabicTime = arabicTime.replaceAll(' hours', ' ساعة');
    arabicTime = arabicTime.replaceAll(' hour', ' ساعة');
    arabicTime = arabicTime.replaceAll(' hrs', ' ساعة');
    arabicTime = arabicTime.replaceAll(' hr', ' ساعة');
    arabicTime = arabicTime.replaceAll(' secs', ' ثانية');
    arabicTime = arabicTime.replaceAll(' sec', ' ثانية');
    arabicTime = arabicTime.replaceAll(' days', ' يوم');
    arabicTime = arabicTime.replaceAll(' day', ' يوم');

    return arabicTime;
  }

  String _convertDistanceToArabic(String? englishDistance) {
    if (englishDistance == null || englishDistance.isEmpty) {
      return '';
    }

    if (AppLocalizations.of(context)!.localeName != 'ar') {
      return englishDistance;
    }

    const englishToArabicNums = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };

    String arabicDistance = englishDistance;

    englishToArabicNums.forEach((english, arabic) {
      arabicDistance = arabicDistance.replaceAll(english, arabic);
    });
    arabicDistance = arabicDistance.replaceAll(' km', ' كم');
    arabicDistance = arabicDistance.replaceAll(' m', ' م');
    arabicDistance = arabicDistance.replaceAll(' mi', ' ميل');
    arabicDistance = arabicDistance.replaceAll(' ft', ' قدم');

    // Add Arabic prefix "على بعد" (at a distance of)
    return 'على بعد $arabicDistance';
  }

  double _calculateStraightDistanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final dlat = (b.latitude - a.latitude) * p;
    final dlon = (b.longitude - a.longitude) * p;
    final lat1 = a.latitude * p;
    final lat2 = b.latitude * p;

    final hav =
        math.pow(math.sin(dlat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
    final distance = 12742 * math.asin(math.sqrt(hav));

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
      return 16.0;
    }

    final distanceBetween = _calculateStraightDistanceKm(
      _customerLatLng!,
      _agentLatLng!,
    );

    if (distanceBetween > 500) {
      return 5.0;
    } else if (distanceBetween > 100) {
      return 7.0;
    } else if (distanceBetween > 50) {
      return 9.0;
    } else if (distanceBetween > 15) {
      return 11.0;
    } else if (distanceBetween > 5) {
      return 13.0;
    } else {
      return 14.0;
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
    log("[LOG] _moveCameraToBounds() called - centering on agent");

    if (_mapController == null) return;

    try {
      final double currentZoom = await _mapController!.getZoomLevel();

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: agentLatLng, zoom: currentZoom),
        ),
      );
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
            child: Text(AppLocalizations.of(context)?.retry ?? "Retry"),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.liveTracking,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading || _scooterIcon == null || _customerIcon == null
          ? Center(child: Loader(color: AppColors.primary))
          : _errorMessage != null
          ? _buildErrorWidget()
          : Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        log(
                          "[MAP_DEBUG] 🗺️ onMapCreated triggered for LiveTrackingPage",
                        );
                        _mapController = controller;
                        if (!_controller.isCompleted) {
                          _controller.complete(controller);
                        }
                        _isMapReady = true;
                        _applyMapStyle();
                        if (_customerLatLng != null && _agentLatLng != null) {
                          log(
                            "[MAP_DEBUG] 📍 Auto-moving camera to bounds on initialization",
                          );
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
                      mapType: MapType.normal,
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
                          ),

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
                            color: const Color(0xFF4A89F3), // Google Maps Blue
                            width: 5,
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
                  booking: widget.booking!,
                  timeTakenToArrive:
                      eta ??
                      (_agentLatLng == null
                          ? AppLocalizations.of(context)!.fetching
                          : AppLocalizations.of(context)!.calculating),
                  remainingKm:
                      distance ??
                      (_agentLatLng == null
                          ? AppLocalizations.of(
                              context,
                            )!.waitingForAgentLocation
                          : ""),
                  worker: widget.booking?.agent,
                ),
              ],
            ),
    );
  }
}
