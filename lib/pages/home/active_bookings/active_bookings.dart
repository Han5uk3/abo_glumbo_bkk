// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:abo_glumbo_bbk/configs/env_config.dart';
import 'package:abo_glumbo_bbk/apis/google_tracking_polylines.dart';
import 'package:abo_glumbo_bbk/common_widgets/live_tracking.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/home/active_bookings/widgets/active_live_tracking_card.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class ActiveBookingsSection extends StatefulWidget {
  final List<BookingModel> activeBookings;
  const ActiveBookingsSection({super.key, required this.activeBookings});

  @override
  State<ActiveBookingsSection> createState() => _ActiveBookingsSectionState();
}

class _ActiveBookingsSectionState extends State<ActiveBookingsSection> {
  // Cache for storing calculated ETAs and arrival times
  Map<String, Map<String, dynamic>> etaData = {};

  // Track which bookings are currently being calculated
  Set<String> calculatingETAs = {};

  // Store live location subscriptions for each agent
  Map<String, StreamSubscription> _agentLocationSubscriptions = {};

  // Store current agent locations with timestamp
  Map<String, Map<String, dynamic>> _agentLiveLocations = {};

  // Track agent UIDs currently being tracked to detect device conflicts
  Map<String, String> _trackingAgentUids = {};

  // PageView controller for auto-scrolling through multiple bookings
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  // Timers for debouncing ETA calculations
  Map<String, Timer> _etaDebounceTimers = {};

  // Timer to enforce notification persistence (re-show if dismissed)
  Timer? _notificationPersistenceTimer;

  // Auto-scroll configuration
  static const Duration _autoScrollInterval = Duration(seconds: 4);
  static const Duration _animationDuration = Duration(milliseconds: 500);
  static const double _viewportFraction = 1.0;

  // Production configuration
  static const bool kDebugMode =
      bool.fromEnvironment('dart.vm.product') == false;
  static const Duration _etaDebounceDelay = Duration(seconds: 2);
  static const Duration _locationTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;
  static const Duration _etaDataCacheTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: _viewportFraction,
      initialPage: 0,
    );
    _initializeETACalculations();

    // Show ongoing tracking notification after a short delay to ensure services are initialized
    // REMOVED: calling this here resets the notification to "generic" state causing flicker.
    // We rely on _startTrackingAgent -> _calculateETA -> _updateTrackingNotification to update it when data is ready.
    /* 
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showTrackingNotification();
      }
    });
    */

    // Start auto-scroll only if there are multiple bookings
    if (widget.activeBookings.length > 1) {
      _startAutoScroll();
    }
  }

  @override
  void didUpdateWidget(ActiveBookingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle changes in bookings
    if (widget.activeBookings != oldWidget.activeBookings) {
      _handleBookingsChanged(oldWidget.activeBookings);
    }

    // Handle changes in number of bookings
    if (widget.activeBookings.length != oldWidget.activeBookings.length) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      if (widget.activeBookings.length > 1) {
        _startAutoScroll();
      } else {
        _autoScrollTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();

    // Cancel all agent location subscriptions
    for (final subscription in _agentLocationSubscriptions.values) {
      subscription.cancel();
    }
    _agentLocationSubscriptions.clear();

    // Cancel all ETA debounce timers
    for (final timer in _etaDebounceTimers.values) {
      timer.cancel();
    }
    _etaDebounceTimers.clear();

    super.dispose();
  }

  /// Safe logging that only works in debug mode
  void _log(String message) {
    if (kDebugMode) {
      log(message);
    }
  }

  /// Handle changes in bookings list
  void _handleBookingsChanged(List<BookingModel> oldBookings) {
    final oldAgentUids = oldBookings
        .where((b) => b.agent?.uid != null)
        .map((b) => b.agent!.uid)
        .toSet();

    final newAgentUids = widget.activeBookings
        .where((b) => b.agent?.uid != null)
        .map((b) => b.agent!.uid)
        .toSet();

    // Cancel subscriptions for agents no longer in the list
    final removedAgents = oldAgentUids.difference(newAgentUids);
    for (final agentUid in removedAgents) {
      _agentLocationSubscriptions[agentUid]?.cancel();
      _agentLocationSubscriptions.remove(agentUid);
      _agentLiveLocations.remove(agentUid);
      _log('[AGENT_TRACKING] Stopped tracking agent: $agentUid');
    }

    // Clear cache for removed bookings
    final newBookingIds = widget.activeBookings.map((b) => b.id).toSet();
    etaData.removeWhere((bookingId, _) => !newBookingIds.contains(bookingId));

    // Initialize tracking for new agents
    _initializeETACalculations();
  }

  /// Initialize ETA calculations for all active bookings
  void _initializeETACalculations() {
    for (final booking in widget.activeBookings) {
      final agentUid = booking.agent?.uid;
      if (agentUid != null && agentUid.isNotEmpty) {
        // Start tracking agent location if not already tracking
        if (!_agentLocationSubscriptions.containsKey(agentUid)) {
          _startTrackingAgent(agentUid, booking.id);
        }
      } else {
        _log('[ETA] ⚠️ No agent UID found for booking ${booking.id}');
        _setFallbackETA(booking.id);
      }
    }
  }

  /// Start tracking agent's live location
  void _startTrackingAgent(String agentUid, String bookingId) {
    _log(
      '[AGENT_TRACKING] Starting to track agent: $agentUid for booking: $bookingId',
    );

    _agentLocationSubscriptions[agentUid] = AppServices()
        .getAgentLiveLocationStream(agentUid)
        .timeout(_locationTimeout)
        .listen(
          (user) {
            final liveLocation = user.liveLocation;
            final lat = liveLocation?.latitude;
            final lng = liveLocation?.longitude;

            if (lat != null && lng != null && _areValidCoordinates(lat, lng)) {
              _log(
                '[AGENT_TRACKING] 🚗 Agent $agentUid location update: $lat, $lng',
              );

              final previousLocation = _agentLiveLocations[agentUid];
              final hasLocationChanged =
                  previousLocation == null ||
                  previousLocation['latitude'] != lat ||
                  previousLocation['longitude'] != lng;

              // Store the live location with timestamp
              _agentLiveLocations[agentUid] = {
                'latitude': lat,
                'longitude': lng,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };

              // Schedule ETA recalculation only if location changed significantly
              if (hasLocationChanged) {
                _scheduleETARecalculationForAgent(agentUid);
              }
            } else {
              _log(
                '[AGENT_TRACKING] ⚠️ Invalid location data for agent $agentUid: $lat, $lng',
              );
            }
          },
          onError: (error) {
            _log('[AGENT_TRACKING] ❌ Error tracking agent $agentUid: $error');
            // Retry tracking after a delay
            Timer(const Duration(seconds: 5), () {
              if (mounted &&
                  _agentLocationSubscriptions.containsKey(agentUid)) {
                _startTrackingAgent(agentUid, bookingId);
              }
            });
          },
        );
  }

  /// Schedule ETA recalculation for all bookings with a specific agent
  void _scheduleETARecalculationForAgent(String agentUid) {
    // Cancel existing timer for this agent
    _etaDebounceTimers[agentUid]?.cancel();

    // Schedule new calculation after a delay to avoid too frequent updates
    _etaDebounceTimers[agentUid] = Timer(_etaDebounceDelay, () {
      if (!mounted) return;

      // Find all bookings with this agent and recalculate their ETAs
      for (final booking in widget.activeBookings) {
        if (booking.agent?.uid == agentUid) {
          _log(
            '[ETA] Scheduled recalculation for booking ${booking.id} with agent $agentUid',
          );
          // Clear cache to force recalculation
          etaData.remove(booking.id);
          calculatingETAs.remove(booking.id);
          _calculateETA(booking);
        }
      }
    });
  }

  /// Start auto-scrolling through bookings
  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;

      final itemCount = widget.activeBookings.length;
      if (itemCount <= 1) return;

      _currentPage = (_currentPage + 1) % itemCount;
      _pageController.animateToPage(
        _currentPage,
        duration: _animationDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  /// Reset auto-scroll timer when user interacts with the page
  void _resetAutoScrollTimer() {
    if (widget.activeBookings.length <= 1) return;
    _autoScrollTimer?.cancel();
    Future.delayed(const Duration(seconds: 2), _startAutoScroll);
  }



  /// Enhanced duration parsing with multiple format support
  int _extractMinutesFromDuration(String duration) {
    if (duration.trim().isEmpty) {
      _log('[ETA] Empty duration string, using fallback');
      return 15;
    }

    _log('[ETA] Parsing duration: "$duration"');

    // Clean the input string
    final cleanDuration = duration.toLowerCase().trim();

    // Pattern 1: Simple formats like "15 min", "30 mins", "5 minutes"
    final RegExp simpleMinRegex = RegExp(r'(\d+)\s*(?:min|minute)s?\b');
    final simpleMatch = simpleMinRegex.firstMatch(cleanDuration);
    if (simpleMatch != null) {
      final minutes = int.tryParse(simpleMatch.group(1) ?? '0') ?? 0;
      _log('[ETA] Extracted simple minutes: $minutes');
      return minutes > 0 ? minutes : 15;
    }

    // Pattern 2: Hour formats like "1 hour", "2 hrs", "1.5 hours"
    final RegExp hourOnlyRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr)s?\b');
    final hourOnlyMatch = hourOnlyRegex.firstMatch(cleanDuration);
    if (hourOnlyMatch != null &&
        !cleanDuration.contains(RegExp(r'\d+\s*(?:min|minute)'))) {
      final hoursStr = hourOnlyMatch.group(1) ?? '0';
      final hours = double.tryParse(hoursStr) ?? 0.0;
      final minutes = (hours * 60).round();
      _log('[ETA] Extracted hour-only: $hours hours = $minutes minutes');
      return minutes > 0 ? minutes : 15;
    }

    // Pattern 3: Complex formats like "1 hour 30 mins", "2 hrs 45 minutes"
    final RegExp hourRegex = RegExp(r'(\d+)\s*(?:hour|hr)s?');
    final RegExp minRegex = RegExp(r'(\d+)\s*(?:min|minute)s?');

    final hourMatch = hourRegex.firstMatch(cleanDuration);
    final minMatch = minRegex.firstMatch(cleanDuration);

    int totalMinutes = 0;

    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '0') ?? 0;
      totalMinutes += hours * 60;
      _log('[ETA] Extracted hours: $hours (${hours * 60} minutes)');
    }

    if (minMatch != null) {
      final minutes = int.tryParse(minMatch.group(1) ?? '0') ?? 0;
      totalMinutes += minutes;
      _log('[ETA] Extracted additional minutes: $minutes');
    }

    // Pattern 4: Just numbers (assume minutes)
    if (totalMinutes == 0) {
      final RegExp numberRegex = RegExp(r'(\d+)');
      final numberMatch = numberRegex.firstMatch(cleanDuration);
      if (numberMatch != null) {
        totalMinutes = int.tryParse(numberMatch.group(1) ?? '0') ?? 0;
        _log('[ETA] Extracted raw number as minutes: $totalMinutes');
      }
    }

    // Fallback to 15 minutes if no valid duration found
    final result = totalMinutes > 0 ? totalMinutes : 15;
    _log('[ETA] Final extracted minutes: $result');
    return result;
  }

  /// Validate coordinates
  bool _areValidCoordinates(double lat, double lng) {
    return lat != 0.0 &&
        lng != 0.0 &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  /// Calculate straight-line distance between two coordinates using Haversine formula
  double _calculateStraightLineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final dlat = (lat2 - lat1) * p;
    final dlng = (lng2 - lng1) * p;
    final a =
        (0.5 - math.cos(dlat) / 2) +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos(dlng)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Calculate arrival time from ETA minutes
  String _calculateArrivalTime(int etaMinutes) {
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: etaMinutes));

    // Format time as HH:MM
    final hour = arrivalTime.hour.toString().padLeft(2, '0');
    final minute = arrivalTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// Validate cached ETA data for multi-device safety
  bool _isValidCachedETA(String bookingId, BookingModel currentBooking) {
    final cachedData = etaData[bookingId];
    if (cachedData == null) return false;

    final cacheTimestamp = cachedData['timestamp'] as int;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;

    // Check if cache is expired
    if (cacheAge > _etaDataCacheTimeout.inMilliseconds) {
      _log('[ETA] Cache expired for booking $bookingId (age: ${cacheAge}ms)');
      return false;
    }

    // Check if this is location error that needs re-validation
    if (cachedData['isLocationError'] == true) {
      _log('[ETA] Cache contains location error, forcing recalculation');
      return false;
    }

    // Verify the booking data hasn't changed
    final cachedAgentUid = cachedData['agentUid'] as String?;
    final currentAgentUid = currentBooking.agent?.uid;

    if (cachedAgentUid != currentAgentUid) {
      _log(
        '[ETA] Agent UID mismatch - Cache: $cachedAgentUid, Current: $currentAgentUid',
      );
      return false;
    }

    // Check if delivery address has changed (customer may have changed selected address on another device)
    final cachedBookingId = cachedData['bookingId'] as String?;
    final currentBookingId = currentBooking.id;

    if (cachedBookingId != currentBookingId) {
      _log(
        '[ETA] Booking ID mismatch - Cache: $cachedBookingId, Current: $currentBookingId (multi-device detection)',
      );
      return false;
    }

    _log(
      '[ETA] Using valid cached data for booking $bookingId (age: ${cacheAge}ms)',
    );
    return true;
  }

  /// Calculate ETA from agent location to customer delivery address with retry logic
  Future<void> _calculateETA(BookingModel booking, [int retryCount = 0]) async {
    final cacheKey = booking.id;

    // Check if we have recent valid data
    if (_isValidCachedETA(cacheKey, booking)) {
      return;
    }

    if (calculatingETAs.contains(booking.id)) {
      _log('[ETA] Already calculating ETA for booking ${booking.id}');
      return;
    }

    final agentUid = booking.agent?.uid;
    if (agentUid == null || agentUid.isEmpty) {
      _log('[ETA] ⚠️ No agent UID for booking ${booking.id}');
      _setFallbackETA(booking.id, agentUid: agentUid);
      return;
    }

    calculatingETAs.add(booking.id);
    _log(
      '[ETA] Starting ETA calculation for booking ${booking.id} with agent $agentUid (attempt ${retryCount + 1})',
    );

    try {
      // Find customer's selected delivery address
      AddressModel? customerSelectedAddress;
      try {
        customerSelectedAddress = booking.customer.addresses.firstWhere(
          (address) => address.isSelected == true,
        );
        _log('[ETA] Found selected address for booking ${booking.id}');
      } catch (e) {
        // Fallback to first address if no selected address
        customerSelectedAddress = booking.customer.addresses.isNotEmpty
            ? booking.customer.addresses.first
            : null;
        _log(
          '[ETA] No selected address, using first available for booking ${booking.id}',
        );
      }

      if (customerSelectedAddress == null) {
        _log('[ETA] ⚠️ No customer address for booking ${booking.id}');
        _setFallbackETA(booking.id, agentUid: agentUid);
        return;
      }

      // Validate delivery address hasn't changed (multi-device safety)
      final cachedData = etaData[booking.id];
      if (cachedData != null &&
          cachedData['customerLat'] != null &&
          cachedData['customerLng'] != null) {
        final cachedCustomerLat = cachedData['customerLat'] as double;
        final cachedCustomerLng = cachedData['customerLng'] as double;
        final currentCustomerLat = customerSelectedAddress.lat ?? 0.0;
        final currentCustomerLng = customerSelectedAddress.lon ?? 0.0;

        // If address coordinates differ by more than 10 meters, recalculate
        final addressDistance = _calculateStraightLineDistance(
          cachedCustomerLat,
          cachedCustomerLng,
          currentCustomerLat,
          currentCustomerLng,
        );

        if (addressDistance > 0.01) {
          _log(
            '[ETA] Delivery address changed (distance: ${addressDistance.toStringAsFixed(3)} km) - recalculating ETA',
          );
          etaData.remove(booking.id);
        }
      }

      // Get agent's live location from our tracked locations
      final agentLocation = _agentLiveLocations[agentUid];
      if (agentLocation == null) {
        _log(
          '[ETA] ⚠️ No live location available for agent $agentUid (booking ${booking.id})',
        );
        _setFallbackETA(booking.id, agentUid: agentUid);
        return;
      }

      final agentLat = agentLocation['latitude'] as double;
      final agentLng = agentLocation['longitude'] as double;
      final customerLat = customerSelectedAddress.lat ?? 0.0;
      final customerLng = customerSelectedAddress.lon ?? 0.0;

      // Validate coordinates
      if (!_areValidCoordinates(agentLat, agentLng)) {
        _log(
          '[ETA] ⚠️ Invalid agent coordinates for booking ${booking.id}: $agentLat, $agentLng',
        );
        _setFallbackETA(booking.id, agentUid: agentUid);
        return;
      }

      if (!_areValidCoordinates(customerLat, customerLng)) {
        _log(
          '[ETA] ⚠️ Invalid customer coordinates for booking ${booking.id}: $customerLat, $customerLng',
        );
        _setFallbackETA(booking.id, agentUid: agentUid);
        return;
      }

      _log('[ETA] Agent live location: $agentLat, $agentLng');
      _log('[ETA] Delivery address: $customerLat, $customerLng');

      // Calculate straight-line distance to validate coordinates
      final straightLineDistance = _calculateStraightLineDistance(
        agentLat,
        agentLng,
        customerLat,
        customerLng,
      );
      _log(
        '[ETA] Straight-line distance: ${straightLineDistance.toStringAsFixed(2)} km',
      );

      // Validate that coordinates are not identical or suspiciously close
      if (straightLineDistance < 0.01) {
        // Less than 10 meters - likely same location (error)
        _log(
          '[ETA] ⚠️ Agent and customer coordinates are identical or too close for booking ${booking.id}',
        );
        _setFallbackETA(booking.id, isLocationError: true, agentUid: agentUid);
        return;
      }

      // Validate that distance is reasonable (not too far)
      if (straightLineDistance > 500) {
        // More than 500km - likely incorrect coordinates
        _log(
          '[ETA] ⚠️ Distance too large (${straightLineDistance.toStringAsFixed(1)} km) - possible location error for booking ${booking.id}',
        );
        _setFallbackETA(booking.id, isLocationError: true, agentUid: agentUid);
        return;
      }

      // Call Google Maps API to get ETA from agent to delivery address
      final result = await getEtaAndDistance(
        originLat: agentLat,
        originLng: agentLng,
        destinationLat: customerLat,
        destinationLng: customerLng,
        apiKey: EnvConfig.googleMapsApiKey,
      ).timeout(const Duration(seconds: 10));

      _log('[ETA] API Response for booking ${booking.id}: $result');

      // Handle different possible response formats
      String? durationString;
      String? distanceString;

      if (result is Map<String, dynamic>) {
        // Try different possible keys for duration
        durationString =
            result['duration'] as String? ??
            result['duration_text'] as String? ??
            result['text'] as String?;

        distanceString = result['distance'] as String?;
      } else if (result is String) {
        durationString = result as String?;
      }

      if (durationString != null && durationString.isNotEmpty) {
        final etaMinutes = _extractMinutesFromDuration(durationString);
        final arrivalTime = _calculateArrivalTime(etaMinutes);

        _log(
          '[ETA] ✅ API Success - Duration: "$durationString", Distance: "$distanceString", Minutes: $etaMinutes, Arrival: $arrivalTime',
        );

        if (mounted) {
          setState(() {
            etaData[booking.id] = {
              'minutes': etaMinutes,
              'arrivalTime': arrivalTime,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'agentUid': booking.agent?.uid,
              'bookingId': booking.id,
              'isLocationError': false,
              'customerLat': customerLat,
              'customerLng': customerLng,
              'distance': distanceString,
            };
          });

          // Trigger local notifications for 10 minutes or nearby
          if (etaMinutes == 10) {
            if (!NotificationServices.hasTriggeredLocalNotification(booking.id, '10_minutes')) {
              NotificationServices.showLocalLiveTrackingNotification(
                type: '10_minutes',
                bookingId: booking.id,
                technicianName: booking.agent?.name ?? 'Technician',
              );
              NotificationServices.markLocalNotificationTriggered(booking.id, '10_minutes');
            }
          } else if (etaMinutes < 5 && etaMinutes >= 0) {
            if (!NotificationServices.hasTriggeredLocalNotification(booking.id, 'nearby')) {
              NotificationServices.showLocalLiveTrackingNotification(
                type: 'nearby',
                bookingId: booking.id,
                technicianName: booking.agent?.name ?? 'Technician',
              );
              NotificationServices.markLocalNotificationTriggered(booking.id, 'nearby');
            }
          }

          // Update the tracking notification with new ETA
          _updateTrackingNotification();
        }
      } else {
        _log('[ETA] ⚠️ No duration found in API response: $result');
        throw Exception('Invalid API response format');
      }
    } catch (e, stackTrace) {
      _log('[ETA] ❌ API Error for booking ${booking.id}: $e');
      if (kDebugMode) {
        _log('[ETA] Stack trace: $stackTrace');
      }

      // Retry logic
      if (retryCount < _maxRetries) {
        _log(
          '[ETA] Retrying calculation for booking ${booking.id} in 5 seconds...',
        );
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _calculateETA(booking, retryCount + 1);
          }
        });
      } else {
        _setFallbackETA(booking.id, agentUid: agentUid);
      }
    } finally {
      calculatingETAs.remove(booking.id);
    }
  }

  /// Set fallback ETA when calculation fails
  void _setFallbackETA(
    String bookingId, {
    bool isLocationError = false,
    String? agentUid,
  }) {
    // Use -1 to indicate location error (will be handled in UI)
    final fallbackMinutes = isLocationError ? -1 : 15;
    final fallbackArrivalTime = isLocationError
        ? '--:--'
        : _calculateArrivalTime(15);

    if (mounted) {
      setState(() {
        etaData[bookingId] = {
          'minutes': fallbackMinutes,
          'arrivalTime': fallbackArrivalTime,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isLocationError': isLocationError,
          'agentUid': agentUid,
          'bookingId': bookingId,
        };
      });
    }

    // Update notification even on fallback to ensure it appears/persists
    _updateTrackingNotification();
    _log(
      '[ETA] Set fallback ETA (${isLocationError ? "location error" : "$fallbackMinutes mins"}, arrival: $fallbackArrivalTime) for booking $bookingId (agent: $agentUid)',
    );
  }

  /// Get customer's selected delivery address for a booking
  AddressModel? _getCustomerSelectedAddress(BookingModel booking) {
    try {
      return booking.customer.addresses.firstWhere(
        (address) => address.isSelected == true,
      );
    } catch (e) {
      return booking.customer.addresses.isNotEmpty
          ? booking.customer.addresses.first
          : null;
    }
  }

  /// Update tracking notification with latest ETA
  Future<void> _updateTrackingNotification() async {
    try {
      final locale = AppLocalizations.of(context);
      if (locale == null) return;

      // Get booking details
      String? serviceName;
      String? bookingId;
      String? notificationBody;

      if (widget.activeBookings.isNotEmpty) {
        final firstBooking = widget.activeBookings[0];
        bookingId = firstBooking.id;

        // Get service name based on app language
        final isArabic = locale.localeName == 'ar';
        serviceName = isArabic
            ? firstBooking.service.name_ar
            : firstBooking.service.name;

        // Get ETA and Distance
        final firstBookingEta = etaData[firstBooking.id];
        if (firstBookingEta != null) {
          final arrivalTimeFormatted =
              firstBookingEta['arrivalTime'] as String?;
          final distance = firstBookingEta['distance'] as String?;

          if (distance != null && arrivalTimeFormatted != null) {
            notificationBody =
                '${locale.yourTechnicianIsOnTheWay} - $distance ${locale.away} ${locale.and} ${locale.arrivalTime} $arrivalTimeFormatted';
          }
        }
      }

      await NotificationServices.showOngoingTrackingNotification(
        title: locale.liveTracking,
        serviceName: serviceName,
        body: notificationBody ?? locale.tapForLiveLocationTracking,
        // We set etaMinutes to null to avoid the default ETA appending, as we include it in the body now
        etaMinutes: null,
        etaTime: null,
        bookingId: bookingId,
      );
    } catch (e) {
      debugPrint('❌ Error updating tracking notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeBookings.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppLocalizations.of(context)!.liveTracking,
              style: DMSansFont.textStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // PageView for active bookings
          SizedBox(
            height: 200, // Adjusted height for the new card design
            child: GestureDetector(
              onTapDown: (_) => _resetAutoScrollTimer(),
              onPanDown: (_) => _resetAutoScrollTimer(),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.activeBookings.length,
                onPageChanged: (index) {
                  _currentPage = index;
                },
                padEnds: false,
                itemBuilder: (context, index) {
                  final booking = widget.activeBookings[index];
                  final customerSelectedAddress = _getCustomerSelectedAddress(
                    booking,
                  );

                  // Display text for locations
                  final toLocationText =
                      customerSelectedAddress?.streetName ??
                      customerSelectedAddress?.streetName ??
                      'Unknown Address';
                  final fromLocationText =
                      booking.agent?.districtName ??
                      booking.agent?.name ??
                      'Unknown Location';

                  // Get ETA data
                  final bookingEtaData = etaData[booking.id];
                  final etaMinutes = bookingEtaData?['minutes'] as int? ?? 15;

                  // Check tracking status
                  final agentUid = booking.agent?.uid;
                  final hasLiveLocation =
                      agentUid != null &&
                      _agentLiveLocations.containsKey(agentUid);
                  final isCalculating = calculatingETAs.contains(booking.id);

                  // Log status for debugging (only in debug mode)
                  if (kDebugMode && !hasLiveLocation && !isCalculating) {
                    _log(
                      '[ETA] No live location for booking ${booking.id}, agent: $agentUid',
                    );
                  }

                  return TrackingCard(
                    etaMinutes: etaMinutes,
                    fromLocation: fromLocationText,
                    booking: booking,
                    toLocation: toLocationText,
                    onTrack:
                        customerSelectedAddress != null && booking.agent != null
                        ? () {
                            _log(
                              '[NAVIGATION] Opening live tracking for booking ${booking.id}',
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LiveTrackingPage(
                                  booking: booking,
                                  selectedAddress: customerSelectedAddress,
                                ),
                              ),
                            );
                          }
                        : () {
                            _log(
                              '[NAVIGATION] ⚠️ Cannot open live tracking - missing data',
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.noLiveTrackingAvailable,
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  );
                },
              ),
            ),
          ),

          // Page indicator for multiple bookings
          if (widget.activeBookings.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.activeBookings.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.blue
                          : Colors.grey.withOpacity(0.4),
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
