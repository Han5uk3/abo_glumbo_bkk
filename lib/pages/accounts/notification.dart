import 'package:abo_glumbo_bbk/services/time_service.dart';
import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/notification.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewNotificationsPage extends StatefulWidget {
  const NewNotificationsPage({super.key});

  @override
  State<NewNotificationsPage> createState() => _NewNotificationsPageState();
}

class _NewNotificationsPageState extends State<NewNotificationsPage> {
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 30;
  int _currentlyDisplayed = 30;
  bool _isLoadingMore = false;

  // Cache the notifications list
  List<NotificationModel> _cachedNotifications = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_isLoadingMore && _cachedNotifications.length > _currentlyDisplayed) {
      setState(() {
        _isLoadingMore = true;
      });

      // Simulate a small delay for smooth UX
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _currentlyDisplayed += _itemsPerPage;
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  String _getRelativeTime(DateTime dateTime, String lanCode) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final isAr = lanCode == 'ar';
    final isUr = lanCode == 'ur';

    if (difference.inSeconds < 60) {
      return isAr
          ? 'الآن'
          : isUr
          ? 'ابھی'
          : 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return isAr
          ? 'منذ $minutes دقيقة'
          : isUr
          ? '$minutes منٹ پہلے'
          : '$minutes min ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return isAr
          ? 'منذ $hours ساعة'
          : isUr
          ? '$hours گھنٹے پہلے'
          : '$hours hr ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return isAr
          ? 'منذ $days يوم'
          : isUr
          ? '$days دن پہلے'
          : '$days day${days > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(KsaTime.fromInstant(dateTime));
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
    final isUr = lanCode == 'ur';

    return StreamBuilder<List<NotificationModel>>(
      stream: AppServices.getNotificationsStream(),
      builder: (context, snapshot) {
        // Update cached notifications when new data arrives
        if (snapshot.hasData) {
          _cachedNotifications = snapshot.data!;
        }

        return Scaffold(
          backgroundColor: AppColors.bgBlueTint,
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              iconSize: 18,
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            ),
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: Text(
              AppLocalizations.of(context)?.notifications ?? 'Notifications',
              style: TextStyle(color: Colors.white),
            ),
            shape: Border.all(style: BorderStyle.none),
            actions: [
              if (_cachedNotifications.any((n) => !n.read))
                IconButton(
                  iconSize: 16,
                  icon: const Icon(
                    Icons.done_all_rounded,
                    color: Colors.black,
                  ),
                  tooltip: isAr
                      ? 'تحديد الكل كمقروء'
                      : isUr
                      ? 'سب کو پڑھا ہوا نشان زد کریں'
                      : 'Mark All Read',
                  onPressed: () async {
                    await AppServices.markAllFirestoreNotificationsAsRead();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          content: Text(
                            isAr
                                ? 'تم تحديد جميع الإشعارات كمقروءة'
                                : isUr
                                ? 'تمام اطلاعات پڑھی ہوئی نشان زد کر دی گئیں'
                                : 'All notifications marked as read',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              if (_cachedNotifications.isNotEmpty)
                IconButton(
                  iconSize: 16,
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.black,
                  ),
                  tooltip: isAr
                      ? 'حذف الكل'
                      : isUr
                      ? 'سب حذف کریں'
                      : 'Delete All',
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        actionsAlignment: MainAxisAlignment.start,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // constraints: const BoxConstraints(maxWidth: 320),
                        backgroundColor: Colors.white,
                        title: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isAr
                                  ? 'حذف الكل'
                                  : isUr
                                  ? 'سب حذف کریں'
                                  : 'Delete All',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                        content: Text(
                          isAr
                              ? 'هل أنت متأكد أنك تريد حذف جميع الإشعارات؟'
                              : isUr
                              ? 'کیا آپ واقعی تمام اطلاعات حذف کرنا چاہتے ہیں؟'
                              : 'Are you sure you want to delete all notifications?',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 15,
                          ),
                        ),
                        actions: [
                          eButton(
                            context: context,
                            backgroundColor: Colors.white,
                            onPressed: () => Navigator.pop(context, false),
                            widget: Text(
                              AppLocalizations.of(context)?.cancel ?? 'Cancel',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          eButton(
                            onPressed: () => Navigator.pop(context, true),
                            context: context,
                            backgroundColor: Colors.red,
                            text:
                                AppLocalizations.of(context)?.delete ??
                                'Delete',
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Center(
                            child: Loader(color: AppColors.primary, size: 40),
                          );
                        },
                      );

                      await AppServices.deleteAllFirestoreNotifications();

                      if (context.mounted) {
                        Navigator.pop(context); // Close the loading dialog
                        setState(() {
                          _cachedNotifications.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isAr
                                      ? 'تم حذف جميع الإشعارات'
                                      : isUr
                                      ? 'تمام اطلاعات حذف کر دی گئیں'
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
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _cachedNotifications.isEmpty) {
                return Center(
                  child: Loader(color: AppColors.primary, size: 30),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              if (_cachedNotifications.isEmpty) {
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
                        isAr
                            ? 'لا توجد إشعارات'
                            : isUr
                            ? 'کوئی اطلاع نہیں'
                            : 'No notifications',
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
                            : isUr
                            ? 'آپ کی اطلاعات یہاں ظاہر ہوں گی'
                            : 'Your notifications will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                );
              }

              // Get the notifications to display (limited by pagination)
              final displayedNotifications = _cachedNotifications
                  .take(_currentlyDisplayed)
                  .toList();
              final hasMore = _cachedNotifications.length > _currentlyDisplayed;

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                itemCount: displayedNotifications.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator at the bottom
                  if (index == displayedNotifications.length) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: _isLoadingMore
                          ? Center(
                              child: Loader(color: AppColors.primary, size: 24),
                            )
                          : const SizedBox.shrink(),
                    );
                  }

                  final notification = displayedNotifications[index];
              

                  // Use fallback if specific language content is missing
                  final title = isAr
                      ? (notification.titleAr.isNotEmpty ? notification.titleAr : notification.titleEn)
                      : isUr 
                          ? (notification.titleUr.isNotEmpty ? notification.titleUr : notification.titleEn)
                          : (notification.titleEn.isNotEmpty ? notification.titleEn : notification.titleAr);

                  final body = isAr
                      ? (notification.bodyAr.isNotEmpty ? notification.bodyAr : notification.bodyEn)
                      : isUr 
                          ? (notification.bodyUr.isNotEmpty ? notification.bodyUr : notification.bodyEn)
                          : (notification.bodyEn.isNotEmpty ? notification.bodyEn : notification.bodyAr);

                  final relativeTime = _getRelativeTime(
                    notification.createdAt,
                    lanCode,
                  );
                  final icon = _getNotificationIcon(notification);
                  final iconColor = _getNotificationColor(notification);

                  return dismissibleWidget(
                    notification,
                    lanCode,
                    context,
                    icon,
                    iconColor,
                    relativeTime,
                    title,
                    body,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget dismissibleWidget(
    NotificationModel notification,
    String lanCode,
    BuildContext context,
    IconData icon,
    Color iconColor,
    String relativeTime,
    String title,
    String body,
  ) {
    final isAr = lanCode == 'ar';
    final isUr = lanCode == 'ur';
    final isArOrUr = isAr || isUr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
          key: Key(notification.id),
          direction: notification.read
              ? DismissDirection.endToStart
              : DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              AppServices.markFirestoreNotificationAsRead(notification.id);
              return false;
            }
            return true;
          },
          background: Container(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xff51C777),
            child: Row(
              children: [
                const Icon(Icons.done_all, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  isAr
                      ? 'مقروء'
                      : isUr
                      ? 'پڑھا ہوا'
                      : "Read",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.red,
            child: const Icon(
              Icons.delete_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              AppServices.deleteFirestoreNotification(notification.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.grey[800],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  content: Text(
                    isAr
                        ? 'تم حذف الإشعار'
                        : isUr
                        ? 'اطلاع حذف کر دی گئی'
                        : 'Notification deleted',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  if (!notification.read) {
                    AppServices.markFirestoreNotificationAsRead(
                      notification.id,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon Container
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: notification.read
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (!notification.read)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: EdgeInsets.only(
                                      left: isArOrUr ? 0 : 6,
                                      right: isArOrUr ? 6 : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: iconColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  relativeTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w400,
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
        ),
      ),
    );
  }
}
