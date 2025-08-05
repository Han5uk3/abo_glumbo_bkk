import 'dart:async';
import 'package:abo_glumbo_bbk/apis/google_tracking_polylines.dart';
import 'package:abo_glumbo_bbk/common_widgets/live_tracking.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/home/active_bookings/widgets/active_live_tracking_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActiveBookingsSection extends StatefulWidget {
  final List<BookingModel> activeBookings;
  const ActiveBookingsSection({super.key, required this.activeBookings});

  @override
  State<ActiveBookingsSection> createState() => _ActiveBookingsSectionState();
}

class _ActiveBookingsSectionState extends State<ActiveBookingsSection> {
  Map<String, int> etaCache = {};
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  static const Duration _autoScrollInterval = Duration(seconds: 4);
  static const Duration _animationDuration = Duration(milliseconds: 500);
  static const double _viewportFraction = 1.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: _viewportFraction,
      initialPage: 0,
    );
    _initializeETACalculations();
    if (widget.activeBookings.length > 1) {
      _startAutoScroll();
    }
  }

  @override
  void didUpdateWidget(ActiveBookingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeBookings != oldWidget.activeBookings) {
      _initializeETACalculations();
    }
    if (widget.activeBookings.length != oldWidget.activeBookings.length) {
      _currentPage = 0;
      _pageController.jumpToPage(0);
      if (widget.activeBookings.length > 1) {
        _startAutoScroll();
      } else {
        _autoScrollTimer?.cancel();
      }
    }
  }

  void _initializeETACalculations() {
    for (final booking in widget.activeBookings) {
      if (!etaCache.containsKey(booking.id)) {
        _calculateETA(booking);
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted) return;
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

  void _resetAutoScrollTimer() {
    if (widget.activeBookings.length <= 1) return;
    _autoScrollTimer?.cancel();
    Future.delayed(const Duration(seconds: 2), _startAutoScroll);
  }

  int _extractMinutesFromDuration(String duration) {
    final RegExp regex = RegExp(r'(\d+)\s*(min|minute)');
    final match = regex.firstMatch(duration.toLowerCase());
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }

    final RegExp hourRegex = RegExp(r'(\d+)\s*(hour|hr)');
    final RegExp minRegex = RegExp(r'(\d+)\s*(min|minute)');

    final hourMatch = hourRegex.firstMatch(duration.toLowerCase());
    final minMatch = minRegex.firstMatch(duration.toLowerCase());

    int totalMinutes = 0;
    if (hourMatch != null) {
      totalMinutes += (int.tryParse(hourMatch.group(1) ?? '0') ?? 0) * 60;
    }
    if (minMatch != null) {
      totalMinutes += int.tryParse(minMatch.group(1) ?? '0') ?? 0;
    }

    return totalMinutes > 0 ? totalMinutes : 15;
  }

  Future<void> _calculateETA(BookingModel booking) async {
    if (etaCache.containsKey(booking.id)) return;

    AddressModel? customerSelectedAddress;
    try {
      customerSelectedAddress = booking.customer.addresses.firstWhere(
        (address) => address.isSelected == true,
      );
    } catch (e) {
      customerSelectedAddress = booking.customer.addresses.isNotEmpty
          ? booking.customer.addresses.first
          : null;
    }
    if (booking.agent?.liveLocation != null &&
        customerSelectedAddress != null) {
      try {
        final result = await getEtaAndDistance(
          originLat: booking.agent!.liveLocation?.latitude ?? 0.0,
          originLng: booking.agent!.liveLocation?.longitude ?? 0.0,
          destinationLat: customerSelectedAddress.lat ?? 0.0,
          destinationLng: customerSelectedAddress.lon ?? 0.0,
          apiKey: "AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o",
        );
        final etaMinutes = _extractMinutesFromDuration(result['duration']);
        if (mounted) {
          setState(() {
            etaCache[booking.id] = etaMinutes;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            etaCache[booking.id] = 15;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          etaCache[booking.id] = 15;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeBookings.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppLocalizations.of(context)!.liveTracking,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.29,
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
                  AddressModel? customerSelectedAddress;
                  try {
                    customerSelectedAddress = booking.customer.addresses
                        .firstWhere((address) => address.isSelected == true);
                  } catch (e) {
                    customerSelectedAddress =
                        booking.customer.addresses.isNotEmpty
                        ? booking.customer.addresses.first
                        : null;
                  }
                  final toLocationText =
                      customerSelectedAddress?.streetName ?? 'Unknown Address';
                  final fromLocationText =
                      booking.agent?.districtName ?? 'Unknown Location';
                  return TrackingCard(
                    etaMinutes: etaCache[booking.id] ?? 15,
                    fromLocation: fromLocationText,
                    booking: booking,
                    onTrack:
                        customerSelectedAddress != null && booking.agent != null
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveTrackingPage(
                                booking: booking,
                                selectedAddress: customerSelectedAddress!,
                              ),
                            ),
                          )
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.noLiveTrackingAvailable,
                                ),
                              ),
                            );
                          },
                    toLocation: toLocationText,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
