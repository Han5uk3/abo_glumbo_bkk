import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/notification.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewNotificationsPage extends StatelessWidget {
  const NewNotificationsPage({super.key});

  String _getRelativeTime(DateTime dateTime, bool isAr) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return isAr ? 'الآن' : 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return isAr ? 'منذ $minutes دقيقة' : '$minutes min ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return isAr ? 'منذ $hours ساعة' : '$hours hr ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return isAr ? 'منذ $days يوم' : '$days day${days > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  IconData _getNotificationIcon(NotificationModel notification) {
    // You can customize this based on notification.data
    final type = notification.data['type'] as String?;

    switch (type) {
      case 'booking':
        return Icons.calendar_today_rounded;
      case 'warranty':
        return Icons.verified_user_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'payment':
        return Icons.payment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(NotificationModel notification) {
    final type = notification.data['type'] as String?;

    switch (type) {
      case 'booking':
        return Colors.blue;
      case 'warranty':
        return Colors.green;
      case 'chat':
        return Colors.purple;
      case 'payment':
        return Colors.orange;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lanCode = LocalStoreHelper.getUserlanguage();
    final isAr = lanCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          AppLocalizations.of(context)?.notifications ?? 'Notifications',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: isAr ? 'حذف الكل' : 'Delete All',
            onPressed: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  constraints: const BoxConstraints(maxWidth: 320),
                  backgroundColor: Colors.white,
                  title: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      Text(
                        isAr ? 'حذف الكل' : 'Delete All',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  content: Text(
                    isAr
                        ? 'هل أنت متأكد أنك تريد حذف جميع الإشعارات؟'
                        : 'Are you sure you want to delete all notifications?',
                    style: TextStyle(color: Colors.grey[700], fontSize: 15),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        AppLocalizations.of(context)?.cancel ?? 'Cancel',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.delete ?? 'Delete',
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AppServices.deleteAllFirestoreNotifications();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            isAr
                                ? 'تم حذف جميع الإشعارات'
                                : 'All notifications deleted',
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: AppServices.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAr ? 'لا توجد إشعارات' : 'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'سيتم عرض إشعاراتك هنا'
                        : 'Your notifications will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];

              // Use fallback if specific language content is missing
              final title = isAr
                  ? (notification.titleAr.isNotEmpty
                        ? notification.titleAr
                        : notification.titleEn)
                  : (notification.titleEn.isNotEmpty
                        ? notification.titleEn
                        : notification.titleAr);

              final body = isAr
                  ? (notification.bodyAr.isNotEmpty
                        ? notification.bodyAr
                        : notification.bodyEn)
                  : (notification.bodyEn.isNotEmpty
                        ? notification.bodyEn
                        : notification.bodyAr);

              final relativeTime = _getRelativeTime(
                notification.createdAt,
                isAr,
              );
              final icon = _getNotificationIcon(notification);
              final iconColor = _getNotificationColor(notification);

              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: isAr
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                onDismissed: (direction) {
                  AppServices.deleteFirestoreNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.grey[800],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      content: Text(
                        isAr ? 'تم حذف الإشعار' : 'Notification deleted',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: notification.read
                        ? null
                        : Border.all(
                            color: iconColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (!notification.read) {
                          AppServices.markFirestoreNotificationAsRead(
                            notification.id,
                          );
                        }
                        // Handle navigation if needed based on data
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: notification.read
                              ? null
                              : LinearGradient(
                                  begin: isAr
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  end: isAr
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  colors: [
                                    iconColor.withOpacity(0.03),
                                    Colors.transparent,
                                  ],
                                ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Container
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: iconColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: notification.read
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                            color: Colors.black87,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      if (!notification.read)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: EdgeInsets.only(
                                            left: isAr ? 0 : 8,
                                            right: isAr ? 8 : 0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: iconColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        relativeTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
