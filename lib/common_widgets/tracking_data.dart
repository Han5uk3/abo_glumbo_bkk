import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/services/chat_services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackingData extends StatelessWidget {
  final String? timeTakenToArrive;
  final String? remainingKm;
  final UserModel? worker;
  final BookingModel booking;

  const TrackingData({
    super.key,
    this.timeTakenToArrive,
    this.worker,
    this.remainingKm,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ETA & Distance Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time / ETA
              Row(
                children: [
                  const Text('⏱️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    timeTakenToArrive ?? '--',
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              // Distance
              if (remainingKm != "") ...{
                Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      Directionality.of(context) == TextDirection.rtl
                          ? remainingKm ?? '--'
                          : "${remainingKm ?? '--'} away",
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              },
            ],
          ),

          const SizedBox(height: 16),

          // Status Message
          Text(
            AppLocalizations.of(context)!.yourTechnicianIsMovingToYourLocation,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 24),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 24),

          // Technician Bottom Card
          Row(
            children: [
              // Avatar / Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child:
                      worker?.profileUrl != null &&
                          worker!.profileUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: worker!.profileUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Profession
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker?.name ?? 'Technician',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker?.role ??
                          'Service Provider', // Assuming role is available or use a default
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (booking.chatroomId.isNotEmpty)
                StreamBuilder<int>(
                  stream: ChatService().getUnreadCountStream(
                    booking.chatroomId,
                  ),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return SizedBox(
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatId: booking.chatroomId,
                                participantName:
                                    booking.agent!.name ?? 'Technician',
                                participantId: booking.agent!.uid ?? '',
                                participantPhoto:
                                    booking.agent!.profileUrl ?? '',
                                customerName:
                                    booking.customer.name ?? 'Customer',
                                customerPhoto: '',
                                bookingId: booking
                                    .id, // Customer model does not have profileUrl yet
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 50,
                              decoration: BoxDecoration(
                                color: AppColors.bgWhite,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26.withAlpha(40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/icons/chat2.png',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Call Button
              if (worker?.phone != null)
                InkWell(
                  onTap: () {
                    launchUrl(
                      Uri.parse('tel:${worker!.phone}'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary, // Main brand color
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16), // Bottom padding
        ],
      ),
    );
  }
}
