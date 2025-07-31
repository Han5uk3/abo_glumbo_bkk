import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/home/active_bookings/widgets/active_live_tracking_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActiveBookingsSection extends StatelessWidget {
  final List<BookingModel> activeBookings;

  const ActiveBookingsSection({super.key, required this.activeBookings});

  @override
  Widget build(BuildContext context) {
    if (activeBookings.isEmpty) return const SizedBox();

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
              itemCount: activeBookings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final booking = activeBookings[index];
                return TrackingCard(
                  etaMinutes: 10,
                  fromLocation: 'SDsdsa',
                  booking: booking,
                  onTrack: () {},
                  toLocation: 'SDsdsa',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
