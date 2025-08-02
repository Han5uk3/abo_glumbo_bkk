import 'dart:developer';

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

  @override
  void initState() {
    super.initState();
    _initializeETACalculations();
  }

  @override
  void didUpdateWidget(ActiveBookingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeBookings != oldWidget.activeBookings) {
      _initializeETACalculations();
    }
  }

  void _initializeETACalculations() {
    for (final booking in widget.activeBookings) {
      if (!etaCache.containsKey(booking.id)) {
        _calculateETA(booking);
      }
    }
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
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.activeBookings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final booking = widget.activeBookings[index];
                log('Processing booking: ${booking.toJson()}');
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
                    booking.agent?.location?.name ?? 'Unknown Location';
                return TrackingCard(
                  etaMinutes: etaCache[booking.id] ?? 15,
                  fromLocation: fromLocationText,
                  booking: booking,
                  onTrack: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LiveTrackingPage(booking: booking),
                    ),
                  ),
                  toLocation: toLocationText,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
