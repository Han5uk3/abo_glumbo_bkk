import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_none,
              color: Colors.white,
              size: 18,
            ),
          ),
          // Unread count badge
          Positioned(
            top: 5,
            right: 2,

            child: StreamBuilder<int>(
              stream: AppServices.getUnreadNotificationsCountStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == 0) {
                  return const SizedBox.shrink();
                }
                final count = snapshot.data!;
                final countText = count > 99 ? '99+' : count.toString();
                return Container(
                  margin: const EdgeInsets.all(0),
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
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Center(
                    child: Text(
                      countText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
