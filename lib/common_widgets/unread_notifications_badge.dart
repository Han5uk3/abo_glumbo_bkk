import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:google_fonts/google_fonts.dart';

class UnreadNotificationBadge extends StatelessWidget {
  final VoidCallback onTap;

  const UnreadNotificationBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Notification icon
          const Icon(Icons.notifications_none, color: Colors.white, size: 24),
          // Unread count badge
          StreamBuilder<int>(
            stream: AppServices.getUnreadNotificationCount(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) {
                return const SizedBox.shrink();
              }

              final count = snapshot.data!;
              final countText = count > 99 ? '99+' : count.toString();

              return Positioned(
                top: -4,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 10,
                    minHeight: 10,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Center(
                    child: Text(
                      countText,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
