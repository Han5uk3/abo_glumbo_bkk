import 'dart:convert';
import 'dart:developer';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  String _currentLanguage = 'en';
  final String _apiKey = 'AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o';
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLanguage = AppLocalizations.of(context)?.localeName ?? 'en';
    if (newLanguage != _currentLanguage) {
      final oldLanguage = _currentLanguage;
      _currentLanguage = newLanguage;

      if (oldLanguage != newLanguage && notifications.isNotEmpty) {
        _loadNotifications();
      }
    }
  }

  @override
  void dispose() {
    // Auto-clear read badge when navigating out
    _markAllAsReadOnExit();
    super.dispose();
  }

  Future<void> _markAllAsReadOnExit() async {
    // Mark all as read when leaving the page
    await AppServices.markAllNotificationsAsRead();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
      notifications = [];
    });

    try {
      final notificationsList = await AppServices.getUserNotifications(
        limit: 50,
      );

      final translatedNotifications = await _translateNotifications(
        notificationsList,
      );

      setState(() {
        notifications = translatedNotifications;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Show loading indicator
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final success = await AppServices.markAllNotificationsAsRead();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Reload notifications
        await _loadNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentLanguage == 'ar'
                  ? 'تم وضع علامة على جميع الإشعارات كمقروءة'
                  : 'All notifications marked as read',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentLanguage == 'ar'
                  ? 'حدث خطأ أثناء المحاولة'
                  : 'Error occurred',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<List<Map<String, dynamic>>> _translateNotifications(
    List<Map<String, dynamic>> notificationsList,
  ) async {
    if (notificationsList.isEmpty) return notificationsList;

    final processedNotifications = notificationsList.map((notification) {
      return Map<String, dynamic>.from(notification);
    }).toList();

    try {
      List<String> textsToTranslate = [];
      List<Map<String, dynamic>> translationMap = [];

      for (int i = 0; i < notificationsList.length; i++) {
        final notification = notificationsList[i];
        final title = notification['title']?.toString().trim() ?? '';
        final body = notification['body']?.toString().trim() ?? '';

        Map<String, dynamic> itemMap = {
          'notificationIndex': i,
          'originalTitle': title,
          'originalBody': body,
          'titleIndex': -1,
          'bodyIndex': -1,
        };

        if (title.isNotEmpty) {
          final cacheKey = '${title}_$_currentLanguage';
          if (_translationCache.containsKey(cacheKey)) {
            processedNotifications[i]['title'] = _translationCache[cacheKey];
          } else {
            bool shouldTranslate = false;
            if (_currentLanguage == 'ar') {
              shouldTranslate = _isPrimaryEnglish(title);
            } else {
              shouldTranslate = _containsArabic(title);
            }

            if (shouldTranslate) {
              itemMap['titleIndex'] = textsToTranslate.length;
              textsToTranslate.add(title);
            }
          }
        }

        if (body.isNotEmpty) {
          final cacheKey = '${body}_$_currentLanguage';
          if (_translationCache.containsKey(cacheKey)) {
            processedNotifications[i]['body'] = _translationCache[cacheKey];
          } else {
            bool shouldTranslate = false;
            if (_currentLanguage == 'ar') {
              shouldTranslate = _isPrimaryEnglish(body);
            } else {
              shouldTranslate = _containsArabic(body);
            }

            if (shouldTranslate) {
              itemMap['bodyIndex'] = textsToTranslate.length;
              textsToTranslate.add(body);
            }
          }
        }

        translationMap.add(itemMap);
      }

      List<String> translatedTexts = [];
      if (textsToTranslate.isNotEmpty) {
        log(
          'Translating ${textsToTranslate.length} texts to $_currentLanguage',
        );
        translatedTexts = await _batchTranslateTexts(
          textsToTranslate,
          _currentLanguage,
        );
        log('Translation completed, got ${translatedTexts.length} results');
      }

      if (translatedTexts.isNotEmpty) {
        for (int i = 0; i < translationMap.length; i++) {
          final item = translationMap[i];
          final notificationIndex = item['notificationIndex'] as int;

          if (notificationIndex < processedNotifications.length) {
            final titleIndex = item['titleIndex'] as int;
            if (titleIndex != -1 && titleIndex < translatedTexts.length) {
              final translatedTitle = translatedTexts[titleIndex];
              processedNotifications[notificationIndex]['title'] =
                  translatedTitle;

              _translationCache['${item['originalTitle']}_$_currentLanguage'] =
                  translatedTitle;
            }

            final bodyIndex = item['bodyIndex'] as int;
            if (bodyIndex != -1 && bodyIndex < translatedTexts.length) {
              final translatedBody = translatedTexts[bodyIndex];
              processedNotifications[notificationIndex]['body'] =
                  translatedBody;

              _translationCache['${item['originalBody']}_$_currentLanguage'] =
                  translatedBody;
            }
          }
        }
      }

      return processedNotifications;
    } catch (e) {
      log('Error in translation: $e');
      return processedNotifications;
    }
  }

  Future<List<String>> _batchTranslateTexts(
    List<String> texts,
    String targetLang,
  ) async {
    if (texts.isEmpty) return [];

    try {
      String sourceLang = targetLang == 'ar' ? 'en' : 'ar';

      final response = await http
          .post(
            Uri.parse(
              'https://translation.googleapis.com/language/translate/v2?key=$_apiKey',
            ),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'AbogalamboApp/1.0',
            },
            body: jsonEncode({
              'q': texts,
              'source': sourceLang,
              'target': targetLang,
              'format': 'text',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = data['data']?['translations'] as List?;

        if (translations != null) {
          return translations
              .map<String>((t) => t['translatedText']?.toString() ?? '')
              .toList();
        }
      } else {
        log('Translation API error: ${response.statusCode} - ${response.body}');
        throw Exception('Translation API error: ${response.statusCode}');
      }
    } catch (e) {
      log('Batch translation error: $e');
      return texts;
    }

    return texts;
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final currentLang = _currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notifications),
        actions: [
          // Delete All button
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    _currentLanguage == 'ar' ? 'حذف الكل' : 'Delete All',
                  ),
                  content: Text(
                    _currentLanguage == 'ar'
                        ? 'هل أنت متأكد أنك تريد حذف جميع الإشعارات؟'
                        : 'Are you sure you want to delete all notifications?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        _currentLanguage == 'ar' ? 'إلغاء' : 'Cancel',
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(_currentLanguage == 'ar' ? 'حذف' : 'Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!mounted) return;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );

                final success = await AppServices.deleteAllNotifications();

                if (!mounted) return;
                Navigator.pop(context); // Close loading dialog

                if (success) {
                  await _loadNotifications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(
                        _currentLanguage == 'ar'
                            ? 'تم حذف جميع الإشعارات'
                            : 'All notifications deleted',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        _currentLanguage == 'ar'
                            ? 'حدث خطأ أثناء الحذف'
                            : 'Error deleting notifications',
                      ),
                    ),
                  );
                }
              }
            },
            tooltip: _currentLanguage == 'ar' ? 'حذف الكل' : 'Delete all',
          ),
          // Mark All as Read button
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: _currentLanguage == 'ar'
                ? 'وضع علامة الكل كمقروء'
                : 'Mark all as read',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: _currentLanguage == 'ar' ? 'تحديث' : 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (kDebugMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue.shade50,
              child: Text(
                'Debug: User Role = customer | Notifications: ${notifications.length}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: isLoading
                ? _buildLoadingState(currentLang)
                : notifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationCard(
                          notifications[index],
                          isRTL,
                          currentLang,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String currentLang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            _getLocalizedText('loadingNotifications'),
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noNotificationsYet,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    bool isRTL,
    String currentLang,
  ) {
    try {
      final createdAt = notification['createdAt'] as Timestamp?;
      final title = notification['title']?.toString().trim();
      final body = notification['body']?.toString().trim();
      final category = notification['category'] ?? 'general';
      final isRead = notification['isRead'] as bool? ?? false;

      final displayTitle = (title?.isNotEmpty == true)
          ? title!
          : (body?.isNotEmpty == true)
          ? body!
          : AppLocalizations.of(context)!.notifications;

      final displayBody = (title?.isNotEmpty == true)
          ? (body?.isNotEmpty == true
                ? body!
                : _getLocalizedText('noAdditionalContent'))
          : _getLocalizedText('tapToViewDetails');

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 2,
        color: isRead ? Colors.grey[100] : Colors.white,
        child: ListTile(
          leading: Tooltip(
            message: _getCategoryName(category),
            child: CircleAvatar(
              backgroundColor: isRead ? Colors.grey[400] : Colors.blue,
              child: Icon(_getCategoryIcon(category), color: Colors.white),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    color: isRead ? Colors.grey[600] : Colors.black,
                  ),
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: isRTL
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                displayBody,
                style: TextStyle(
                  color: isRead ? Colors.grey[500] : Colors.grey[700],
                ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatTime(createdAt.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: isRead ? Colors.grey[300] : Colors.grey[400],
                  ),
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'booking':
        return Icons.calendar_today;
      case 'service':
        return Icons.build;
      case 'payment':
        return Icons.payment;
      case 'order':
        return Icons.shopping_cart;
      case 'account':
        return Icons.person;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  String _getCategoryName(String category) {
    if (_currentLanguage == 'ar') {
      switch (category.toLowerCase()) {
        case 'booking':
          return 'حجز';
        case 'service':
          return 'خدمة';
        case 'payment':
          return 'دفع';
        case 'order':
          return 'طلب';
        case 'account':
          return 'حساب';
        case 'promotion':
          return 'عرض';
        default:
          return 'إشعار';
      }
    } else {
      switch (category.toLowerCase()) {
        case 'booking':
          return 'Booking';
        case 'service':
          return 'Service';
        case 'payment':
          return 'Payment';
        case 'order':
          return 'Order';
        case 'account':
          return 'Account';
        case 'promotion':
          return 'Promotion';
        default:
          return 'Notification';
      }
    }
  }

  bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    return text.runes.any((rune) => rune >= 0x0600 && rune <= 0x06FF);
  }

  bool _isPrimaryEnglish(String text) {
    if (text.isEmpty) return true;
    final englishChars = text.runes
        .where(
          (rune) =>
              (rune >= 0x0041 && rune <= 0x005A) ||
              (rune >= 0x0061 && rune <= 0x007A),
        )
        .length;
    final totalChars = text.replaceAll(RegExp(r'[^\w]'), '').length;
    return totalChars == 0 || (englishChars / totalChars) > 0.5;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return _formatTimeUnit(difference.inDays, 'day');
    } else if (difference.inHours > 0) {
      return _formatTimeUnit(difference.inHours, 'hour');
    } else if (difference.inMinutes > 0) {
      return _formatTimeUnit(difference.inMinutes, 'minute');
    } else {
      return _getLocalizedText('justNow');
    }
  }

  String _formatTimeUnit(int value, String unit) {
    if (_currentLanguage == 'ar') {
      String unitText;
      switch (unit) {
        case 'day':
          unitText = value == 1
              ? 'يوم'
              : value == 2
              ? 'يومين'
              : 'أيام';
          break;
        case 'hour':
          unitText = value == 1
              ? 'ساعة'
              : value == 2
              ? 'ساعتين'
              : 'ساعات';
          break;
        case 'minute':
          unitText = value == 1
              ? 'دقيقة'
              : value == 2
              ? 'دقيقتين'
              : 'دقائق';
          break;
        default:
          unitText = unit;
      }
      return 'منذ $value $unitText';
    } else {
      String unitText = _getLocalizedText(unit);
      if (value > 1) unitText += 's';
      return '$value $unitText ${_getLocalizedText('ago')}';
    }
  }

  String _getLocalizedText(String key) {
    switch (key) {
      case 'noAdditionalContent':
        return _currentLanguage == 'ar'
            ? 'لا يوجد محتوى إضافي'
            : 'No additional content';
      case 'tapToViewDetails':
        return _currentLanguage == 'ar'
            ? 'اضغط لعرض التفاصيل'
            : 'Tap to view details';
      case 'day':
        return _currentLanguage == 'ar' ? 'يوم' : 'day';
      case 'hour':
        return _currentLanguage == 'ar' ? 'ساعة' : 'hour';
      case 'minute':
        return _currentLanguage == 'ar' ? 'دقيقة' : 'minute';
      case 'ago':
        return _currentLanguage == 'ar' ? 'منذ' : 'ago';
      case 'justNow':
        return _currentLanguage == 'ar' ? 'الآن' : 'Just now';
      case 'loadingNotifications':
        return _currentLanguage == 'ar'
            ? 'جاري تحميل الإشعارات...'
            : 'Loading notifications...';
      case 'refreshing':
        return _currentLanguage == 'ar' ? 'جاري التحديث...' : 'Refreshing...';
      default:
        return key;
    }
  }
}
