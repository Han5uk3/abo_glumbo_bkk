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

/// A raw GPS fix projected onto the drawn route.
class _RouteSnap {
  const _RouteSnap({
    required this.position,
    required this.bearing,
    required this.offsetMeters,
    required this.segmentIndex,
  });

  /// The point on the polyline, which is what gets drawn.
  final LatLng position;

  /// Compass bearing of the segment [position] landed on.
  final double bearing;

  /// Distance from the raw fix to [position]; how far off the line the driver
  /// appeared to be.
  final double offsetMeters;

  /// Index of that segment's first point in the route list.
  final int segmentIndex;
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  BitmapDescriptor? _driverCarIcon;
  BitmapDescriptor? _customerIcon;

  LatLng? _customerLatLng;
  LatLng? _agentLatLng;
  LatLng? _previousAgentLatLng;
  double _agentBearing = 0.0;

  final ValueNotifier<Set<Marker>> _markersNotifier =
      ValueNotifier<Set<Marker>>({});
  bool _showRecenterButton = false;
  bool _isProgrammaticMove = false;
  bool _hasInitiallyFitRoute = false;
  LatLng? _lastRouteFetchLocation;
  static const double _routeUpdateDistanceMeters = 50.0;

  /// Index of the route segment the vehicle was last snapped onto. Snapping
  /// searches forward from here first so the marker cannot jump backwards
  /// where the route passes close to itself - a divided highway, a U-turn, or
  /// a road the route uses twice.
  int _lastSnapSegment = 0;

  /// How far a raw GPS fix may sit from the drawn route and still be treated
  /// as being on it. Beyond this the fix is trusted as-is: the driver has
  /// genuinely left the route and the drawn line is stale until the next
  /// Directions refresh.
  static const double _maxSnapMeters = 60.0;

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
    _lastTrackedAgentUid = widget.booking?.activeAgent?.uid;
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
    _markersNotifier.dispose();
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

        final agentUid = widget.booking?.activeAgent?.uid;
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
      _driverCarIcon =
          await _getResizedMarker(
        'assets/images/drivercar.png',
        140,
      );
      _customerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
    } catch (_) {
      _driverCarIcon = BitmapDescriptor.defaultMarker;
      _customerIcon = BitmapDescriptor.defaultMarker;
    }
    _updateMarkers();
  }

  void _updateMarkers({LatLng? agentPos, double? bearing}) {
    final pos = agentPos ?? _agentLatLng;
    final b = bearing ?? _agentBearing;
    final markers = <Marker>{};

    if (_customerLatLng != null && _customerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerLatLng!,
          icon: _customerIcon!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (pos != null && _driverCarIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('agent'),
          position: pos,
          icon: _driverCarIcon!,
          rotation: b,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: InfoWindow(
            title: widget.booking?.activeAgent?.name ?? 'Delivery Agent',
            snippet: 'Live location',
          ),
        ),
      );
    }

    _markersNotifier.value = markers;
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
      });
      _updateMarkers();
      if (_agentLatLng != null && _isMapReady && !_hasInitiallyFitRoute) {
        _hasInitiallyFitRoute = true;
        _fitRouteBounds();
      }
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

            if (_agentLatLng == null) {
              _agentLatLng = newAgentLatLng;
              _previousAgentLatLng = newAgentLatLng;
              _lastRouteFetchLocation = newAgentLatLng;
              _updateMarkers(agentPos: newAgentLatLng, bearing: _agentBearing);
              _fetchETAAndRoute();
              if (_isMapReady && !_hasInitiallyFitRoute) {
                _hasInitiallyFitRoute = true;
                _fitRouteBounds();
              }
              return;
            }

            if (_agentLatLng!.latitude != newAgentLatLng.latitude ||
                _agentLatLng!.longitude != newAgentLatLng.longitude) {
              final distanceMovedMeters = _calculateStraightDistanceKm(
                _lastRouteFetchLocation ?? _agentLatLng!,
                newAgentLatLng,
              ) * 1000.0;

              debugPrint(
                '🚗 [AGENT] Distance since last route update: ${distanceMovedMeters.toStringAsFixed(1)}m',
              );

              // Smoothly animate the vehicle pin
              _animateAgentMarker(newAgentLatLng);

              // Update route from Google Directions API every 50 meters travelled
              if (_lastRouteFetchLocation == null ||
                  distanceMovedMeters >= _routeUpdateDistanceMeters) {
                _lastRouteFetchLocation = newAgentLatLng;
                _scheduleFetchETA();
              }

              if (_isFollowingAgent && _mapController != null) {
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
    final currentAgentUid = widget.booking?.activeAgent?.uid;
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
        final technicianName =
            widget.booking?.activeAgent?.name ?? 'Technician';

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
          // Segment indices belong to the list they were measured against.
          _lastSnapSegment = 0;
          debugPrint(
            '[LOG] Route points updated: ${routePoints.length} points',
          );
          if (_agentLatLng != null) {
            final snap = _snapToRoute(_agentLatLng!, routePoints);
            if (snap != null) {
              _agentLatLng = snap.position;
              _agentBearing = snap.bearing;
              _updateMarkers();
            }
          }

          if (!_hasInitiallyFitRoute && _isMapReady) {
            _hasInitiallyFitRoute = true;
            _fitRouteBounds();
          }
        } else {
          routePoints = [_agentLatLng!, _customerLatLng!];
          debugPrint('[LOG] Using fallback straight line route');
        }

        // Update tracking metadata for multi-device safety
        _lastETAUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
        _lastTrackedAgentUid = widget.booking?.activeAgent?.uid;
      });

      if (_isFollowingAgent && _mapController != null) {
        _debouncedCameraUpdate();
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
        _lastTrackedAgentUid = widget.booking?.activeAgent?.uid;
      });

      if (_isFollowingAgent && _mapController != null) {
        _debouncedCameraUpdate();
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

  double _calculateBearing(LatLng start, LatLng end) {
    const p = math.pi / 180.0;
    final lat1 = start.latitude * p;
    final lon1 = start.longitude * p;
    final lat2 = end.latitude * p;
    final lon2 = end.longitude * p;

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * (180.0 / math.pi) + 360.0) % 360.0;
    return degrees;
  }

  /// Drops a raw GPS fix onto the drawn route.
  ///
  /// Two things were wrong before, and they were separate problems that both
  /// read as "the van is not on the line":
  ///
  /// * Position - the marker was drawn at the raw fix. Directions snaps the
  ///   route it returns to the road centreline, so a fix that is 15-25m off
  ///   (normal in a street canyon) puts the van beside the blue line even
  ///   when the driver is exactly on the road.
  /// * Heading - the bearing came from the straight line between two
  ///   consecutive pings. That cuts every corner, and while the vehicle is
  ///   stopped it spins with GPS jitter, because a 3m wobble is still a
  ///   bearing.
  ///
  /// Projecting onto the polyline fixes both at once: the returned point is on
  /// the line the user can see, and the tangent of the segment it landed on is
  /// the direction that stretch of road actually runs.
  _RouteSnap? _snapToRoute(LatLng raw, List<LatLng> points) {
    if (points.length < 2) return null;

    // Flat-earth projection is accurate well past the scale of one route
    // segment, and avoids a trig call per point on every animation frame.
    const metersPerDegLat = 111320.0;
    final metersPerDegLng =
        metersPerDegLat * math.cos(raw.latitude * math.pi / 180.0);

    _RouteSnap? best;

    void scan(int from) {
      for (int i = from; i < points.length - 1; i++) {
        final a = points[i];
        final b = points[i + 1];

        final bx = (b.longitude - a.longitude) * metersPerDegLng;
        final by = (b.latitude - a.latitude) * metersPerDegLat;
        final px = (raw.longitude - a.longitude) * metersPerDegLng;
        final py = (raw.latitude - a.latitude) * metersPerDegLat;

        final lengthSquared = bx * bx + by * by;
        if (lengthSquared <= 0) continue; // duplicate point, no direction

        final t = ((px * bx + py * by) / lengthSquared).clamp(0.0, 1.0);
        final dx = px - bx * t;
        final dy = py - by * t;
        final offset = math.sqrt(dx * dx + dy * dy);

        if (best == null || offset < best!.offsetMeters) {
          best = _RouteSnap(
            position: LatLng(
              a.latitude + (by * t) / metersPerDegLat,
              a.longitude + (bx * t) / metersPerDegLng,
            ),
            bearing: _calculateBearing(a, b),
            offsetMeters: offset,
            segmentIndex: i,
          );
        }
      }
    }

    // Forward from where we were last, so progress along the route stays
    // monotonic. Only fall back to the whole route when that finds nothing
    // plausible - the driver has jumped, or the route was just replaced.
    scan(_lastSnapSegment);
    if (best == null || best!.offsetMeters > _maxSnapMeters) {
      best = null;
      scan(0);
    }

    if (best == null || best!.offsetMeters > _maxSnapMeters) return null;
    _lastSnapSegment = best!.segmentIndex;
    return best;
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
    Timer.periodic(const Duration(seconds: 4), (timer) {
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

      final distanceMovedMeters = _calculateStraightDistanceKm(
        _lastRouteFetchLocation ?? _agentLatLng!,
        newAgent,
      ) * 1000.0;

      _animateAgentMarker(newAgent);

      if (_lastRouteFetchLocation == null ||
          distanceMovedMeters >= _routeUpdateDistanceMeters) {
        _lastRouteFetchLocation = newAgent;
        _fetchETAAndRoute();
      }

      if (_isFollowingAgent && _isMapReady) _debouncedCameraUpdate();
    });
  }

  void _debouncedCameraUpdate() {
    if (!_isFollowingAgent || _mapController == null || _agentLatLng == null) return;
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!_isFollowingAgent || _mapController == null || _agentLatLng == null) return;
      _isProgrammaticMove = true;
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_agentLatLng!),
      ).then((_) {
        _isProgrammaticMove = false;
      });
    });
  }

  void _recenterOnAgent() async {
    if (_agentLatLng == null || _mapController == null) return;
    setState(() {
      _isFollowingAgent = true;
      _showRecenterButton = false;
    });

    _isProgrammaticMove = true;
    try {
      final double currentZoom = await _mapController!.getZoomLevel();
      final double targetZoom = math.max(currentZoom, 16.5);
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _agentLatLng!, zoom: targetZoom),
        ),
      );
    } catch (e) {
      debugPrint('[MAP] Recenter error: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isProgrammaticMove = false;
      });
    }
  }

  void _fitRouteBounds({double padding = 80.0}) async {
    if (_mapController == null) return;

    final points = <LatLng>[];
    if (routePoints.isNotEmpty) {
      points.addAll(routePoints);
    }
    if (_agentLatLng != null) points.add(_agentLatLng!);
    if (_customerLatLng != null) points.add(_customerLatLng!);

    if (points.isEmpty) return;

    _isProgrammaticMove = true;
    try {
      if (points.length == 1) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15.0),
        );
      } else {
        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;

        for (final p in points) {
          minLat = math.min(minLat, p.latitude);
          maxLat = math.max(maxLat, p.latitude);
          minLng = math.min(minLng, p.longitude);
          maxLng = math.max(maxLng, p.longitude);
        }

        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, padding),
        );
      }
    } catch (e) {
      debugPrint('[MAP] Error fitting bounds: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _isProgrammaticMove = false;
      });
    }
  }

  void _animateAgentMarker(LatLng newLoc) {
    _agentMarkerAnimTimer?.cancel();

    if (_agentLatLng == null) {
      final firstSnap = _snapToRoute(newLoc, routePoints);
      final firstPos = firstSnap?.position ?? newLoc;
      if (firstSnap != null) _agentBearing = firstSnap.bearing;
      _agentLatLng = firstPos;
      _previousAgentLatLng = firstPos;
      _updateMarkers(agentPos: firstPos, bearing: _agentBearing);
      return;
    }

    final start = _agentLatLng!;
    final double startBearing = _agentBearing;
    double targetBearing = startBearing;

    // Ride the drawn route where we can: both the point animated towards and
    // the heading come off the polyline, so the van tracks the blue line
    // instead of the raw fix.
    final snap = _snapToRoute(newLoc, routePoints);
    final target = snap?.position ?? newLoc;

    if (snap != null) {
      targetBearing = snap.bearing;
      _agentBearing = targetBearing;
    } else if (_calculateStraightDistanceKm(start, newLoc) > 0.001) {
      // Off-route, or no route yet - the ping-to-ping heading is all there is.
      // The 1m gate keeps a parked vehicle from spinning on GPS jitter.
      targetBearing = _calculateBearing(start, newLoc);
      _agentBearing = targetBearing;
    }

    int current = 0;
    const animFrames = 30;
    const animDuration = Duration(milliseconds: 900);
    final frameInterval = animDuration ~/ animFrames;

    _agentMarkerAnimTimer = Timer.periodic(frameInterval, (timer) {
      current++;
      final t = (current / animFrames).clamp(0.0, 1.0);
      final curvedT = Curves.easeInOutCubic.transform(t);
      final lat = start.latitude + (target.latitude - start.latitude) * curvedT;
      final lng =
          start.longitude + (target.longitude - start.longitude) * curvedT;
      final currentPos = LatLng(lat, lng);
      _agentLatLng = currentPos;

      final currentBearing =
          _interpolateAngle(startBearing, targetBearing, curvedT);

      // Update only marker ValueNotifier — DOES NOT refresh or rebuild the whole map widget!
      _updateMarkers(agentPos: currentPos, bearing: currentBearing);

      if (current >= animFrames) {
        timer.cancel();
        _previousAgentLatLng = target;
        _agentMarkerAnimTimer = null;
      }
    });
  }

  double _interpolateAngle(double from, double to, double t) {
    double diff = (to - from) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return (from + diff * t + 360.0) % 360.0;
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
      body: _isLoading || _driverCarIcon == null || _customerIcon == null
          ? Center(child: Loader(color: AppColors.primary))
          : _errorMessage != null
          ? _buildErrorWidget()
          : Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Listener(
                          onPointerDown: (_) {
                            if (_isFollowingAgent) {
                              setState(() {
                                _isFollowingAgent = false;
                                _showRecenterButton = true;
                              });
                            }
                          },
                          child: ValueListenableBuilder<Set<Marker>>(
                            valueListenable: _markersNotifier,
                            builder: (context, markers, _) {
                              return GoogleMap(
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
                                  _updateMarkers();
                                  if (!_hasInitiallyFitRoute &&
                                      (_customerLatLng != null ||
                                          _agentLatLng != null)) {
                                    _hasInitiallyFitRoute = true;
                                    _fitRouteBounds();
                                  }
                                },
                                onCameraMoveStarted: () {
                                  if (!_isProgrammaticMove &&
                                      _isFollowingAgent) {
                                    setState(() {
                                      _isFollowingAgent = false;
                                      _showRecenterButton = true;
                                    });
                                  }
                                },
                                onCameraMove: (position) {
                                  if (!_isProgrammaticMove &&
                                      _isFollowingAgent) {
                                    setState(() {
                                      _isFollowingAgent = false;
                                      _showRecenterButton = true;
                                    });
                                  }
                                },
                                initialCameraPosition: CameraPosition(
                                  target: _customerLatLng ??
                                      _agentLatLng ??
                                      _mockCustomerLocation,
                                  zoom: _getInitialZoom(),
                                ),
                                mapType: MapType.normal,
                                trafficEnabled: _showTrafficLayer,
                                myLocationEnabled: false,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                compassEnabled: false,
                                markers: markers,
                                polylines: {
                                  if (routePoints.isNotEmpty)
                                    Polyline(
                                      polylineId: const PolylineId("route"),
                                      color: const Color(
                                        0xFF4A89F3,
                                      ), // Google Maps Blue
                                      width: 5,
                                      startCap: Cap.roundCap,
                                      endCap: Cap.roundCap,
                                      jointType: JointType.round,
                                      points: routePoints,
                                    ),
                                },
                              );
                            },
                          ),
                        ),

                        // "View Full Route" Floating Button
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            elevation: 4,
                            shadowColor: Colors.black26,
                            shape: const CircleBorder(),
                            color: Colors.white,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                setState(() {
                                  _isFollowingAgent = false;
                                  _showRecenterButton = true;
                                });
                                _fitRouteBounds();
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.route_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // "Recenter on Technician" Floating Button
                        if (_showRecenterButton)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Material(
                              elevation: 5,
                              shadowColor: Colors.black26,
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: _recenterOnAgent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.my_location_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppLocalizations.of(context)?.localeName ==
                                                'ar'
                                            ? 'إعادة التوسيط'
                                            : (AppLocalizations.of(context)
                                                        ?.localeName ==
                                                    'ur'
                                                ? 'دوبارہ مرکز'
                                                : 'Re-center'),
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
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
                  worker: widget.booking?.activeAgent,
                ),
              ],
            ),
    );
  }
}
