import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/services/chat_services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> _openOrCreateChat(BuildContext context) async {
    final chatService = ChatService();

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          // constraints: BoxConstraints(minWidth: 100),
          content: SizedBox(
            height: 70,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 24, child: Loader(color: AppColors.primary)),
                  Text(AppLocalizations.of(context)!.loadingChat),
                ],
              ),
            ),
          ),
        ),
      );

      String chatId;

      // Check if chatroom exists
      if (booking.chatroomId != null && booking.chatroomId.isNotEmpty) {
        chatId = booking.chatroomId;
      } else {
        // Create new chatroom
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        chatId = await chatService.createChat(
          booking.id,
          booking.agent!.uid ?? '',
          booking.agent!.name ?? 'Technician',
          booking.agent!.profileUrl ?? '',
          booking.customer.name ?? 'Customer',
          '', // Customer photo - update if available
          'customer',
        );

        await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
          'chatroomId': chatId,
        });
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Open chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              participantName: booking.agent!.name ?? 'Technician',
              participantId: booking.agent!.uid ?? '',
              participantPhoto: booking.agent!.profileUrl ?? '',
              customerName: booking.customer.name ?? 'Customer',
              customerPhoto: '',
              bookingId: booking.id,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
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
                    style: DMSansFont.textStyle(
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
                      style: DMSansFont.textStyle(
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
            style: DMSansFont.textStyle(
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
                      style: DMSansFont.textStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker?.role ?? 'Service Provider',
                      style: DMSansFont.textStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Chat Button with unread indicator
              StreamBuilder<int>(
                stream: booking.chatroomId.isNotEmpty
                    ? ChatService().getUnreadCountStream(booking.chatroomId)
                    : Stream.value(0),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  return SizedBox(
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _openOrCreateChat(context),
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
                      color: AppColors.primary,
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
