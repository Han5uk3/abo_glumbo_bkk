import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/notification.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewNotificationsPage extends StatelessWidget {
  const NewNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lanCode = LocalStoreHelper.getUserlanguage();
    final isAr = lanCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.notifications ?? 'Notifications',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  actionsAlignment: MainAxisAlignment.start,
                  title: Text(isAr ? 'حذف الكل' : 'Delete All'),
                  content: Text(
                    isAr
                        ? 'هل أنت متأكد أنك تريد حذف جميع الإشعارات؟'
                        : 'Are you sure you want to delete all notifications?',
                  ),
                  actions: [
                    TextButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Colors.red),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        AppLocalizations.of(context)?.delete ?? 'Delete',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        AppLocalizations.of(context)?.cancel ?? 'Cancel',
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
                      content: Text(
                        isAr
                            ? 'تم حذف جميع الإشعارات'
                            : 'All notifications deleted',
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Text(isAr ? 'لا توجد إشعارات' : 'No notifications'),
            );
          }

          return ListView.builder(
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

              final time = DateFormat(
                'MMM d, h:mm a',
              ).format(notification.createdAt);

              return ListTile(
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: notification.read
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                tileColor: notification.read
                    ? null
                    : Colors.blue.withOpacity(0.05),
                onTap: () {
                  if (!notification.read) {
                    AppServices.markFirestoreNotificationAsRead(
                      notification.id,
                    );
                  }
                  // Handle navigation if needed based on data
                },
              );
            },
          );
        },
      ),
    );
  }
}