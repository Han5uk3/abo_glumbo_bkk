import 'dart:developer';
import 'dart:convert';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  DocumentSnapshot? lastDoc;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  final int pageSize = 10;
  late ScrollController _scrollController;

  // Translation system with enhanced caching
  String _currentLanguage = 'en';
  final String _apiKey = 'AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o';

  // NEW: Enhanced cache structure
  // Cache structure: {language: {notificationId: {title: translated, body: translated, timestamp: DateTime}}}
  static final Map<String, Map<String, Map<String, dynamic>>>
  _notificationCache = {};

  // NEW: Track cached notification IDs for current language
  Set<String> get _cachedNotificationIds =>
      _notificationCache[_currentLanguage]?.keys.toSet() ?? {};

  // Set to track unique notifications (title + datetime)
  final Set<String> _notificationKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLanguage = AppLocalizations.of(context)?.localeName ?? 'en';
    if (newLanguage != _currentLanguage) {
      _currentLanguage = newLanguage;
      // Don't clear cache when language changes, just reload from cache
      if (notifications.isNotEmpty) {
        _loadFromCacheOrRefresh();
      }
    }
  }

  @override
  void dispose() {
    // AUTO-MARK: Mark all notifications as read when leaving the page
    AppServices.markAllNotificationsAsRead();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadInitialNotifications();
    } catch (e) {
      log('Error initializing app: $e');
      setState(() => isLoading = false);
    }
  }

  // Simple refresh method that just reloads the page
  Future<void> _refreshPage() async {
    try {
      lastDoc = null;
      hasMore = true;
      _notificationKeys.clear();

      setState(() {
        notifications = [];
        isLoading = true;
      });

      await _loadInitialNotifications();
    } catch (e) {
      log('Error refreshing page: $e');
      _showErrorSnackBar(
        AppLocalizations.of(context)!.errorRefreshingNotifications,
      );
    }
  }

  // NEW: Method to load from cache first, then refresh if needed
  Future<void> _loadFromCacheOrRefresh() async {
    try {
      // First, try to load from cache
      if (_cachedNotificationIds.isNotEmpty) {
        log('Loading notifications from cache for language: $_currentLanguage');
        await _loadNotificationsFromCache();
      } else {
        log(
          'No cache found for language: $_currentLanguage, loading fresh data',
        );
        await _refreshNotifications();
      }
    } catch (e) {
      log('Error in _loadFromCacheOrRefresh: $e');
      await _refreshNotifications();
    }
  }

  // NEW: Load notifications from cache
  Future<void> _loadNotificationsFromCache() async {
    setState(() => isLoading = true);

    try {
      // Get fresh data from Firestore (without translation)
      final query = await _getNotificationsQuery().get();
      final validDocs = _filterValidNotifications(query.docs);

      if (validDocs.isEmpty) {
        setState(() {
          notifications = [];
          hasMore = false;
          isLoading = false;
        });
        return;
      }

      // Process notifications and apply cached translations
      final processedNotifications = <Map<String, dynamic>>[];

      for (final doc in validDocs) {
        final data = Map<String, dynamic>.from(
          doc.data() as Map<String, dynamic>,
        );
        data['id'] = doc.id;

        // Check if translation exists in cache
        final cachedTranslation = _notificationCache[_currentLanguage]?[doc.id];
        if (cachedTranslation != null) {
          // Use cached translation
          data['title'] = cachedTranslation['title'] ?? data['title'];
          data['body'] = cachedTranslation['body'] ?? data['body'];
          log('Using cached translation for notification: ${doc.id}');
        }

        processedNotifications.add(data);
      }

      // Remove duplicates and update state
      final uniqueNotifications = _removeDuplicates(processedNotifications);

      setState(() {
        notifications = uniqueNotifications;
        lastDoc = validDocs.isNotEmpty ? validDocs.last : null;
        hasMore = query.docs.length == pageSize;
        isLoading = false;
      });
    } catch (e) {
      log('Error loading from cache: $e');
      setState(() => isLoading = false);
    }
  }

  // MODIFIED: Refresh method now forces translation API call
  Future<void> _refreshNotifications({bool forceTranslation = false}) async {
    try {
      lastDoc = null;
      hasMore = true;
      _notificationKeys.clear();

      setState(() {
        notifications = [];
        isLoading = true;
      });

      if (forceTranslation) {
        log('Force refresh: Clearing cache for language: $_currentLanguage');
        _notificationCache[_currentLanguage]?.clear();
      }

      await _loadInitialNotifications();
    } catch (e) {
      log('Error refreshing notifications: $e');
      _showErrorSnackBar(
        AppLocalizations.of(context)!.errorRefreshingNotifications,
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      _loadMoreNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.markAllAsRead ?? 'Mark All as Read',
        ),
        content: Text(
          AppLocalizations.of(context)?.markAllAsReadMessage ??
              'Are you sure you want to mark all notifications as read?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.confirm ?? 'Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppServices.markAllNotificationsAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.allMarkedAsRead ??
                  'All notifications marked as read',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        // Refresh the page to reflect changes
        await _refreshPage();
      }
    }
  }

  String _createNotificationKey(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim() ?? '';
    final createdAt = data['createdAt']?.toDate();

    if (title.isEmpty || createdAt == null) {
      return data['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
    return '${title}_$dateStr';
  }

  List<Map<String, dynamic>> _removeDuplicates(
    List<Map<String, dynamic>> notificationsList,
  ) {
    final List<Map<String, dynamic>> uniqueNotifications = [];
    final Set<String> seenKeys = Set<String>.from(_notificationKeys);

    for (final notification in notificationsList) {
      final key = _createNotificationKey(notification);

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueNotifications.add(notification);
      } else {
        log('Duplicate notification removed: $key');
      }
    }

    _notificationKeys.addAll(seenKeys);
    return uniqueNotifications;
  }

  Future<void> _loadInitialNotifications() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      final query = await _getNotificationsQuery().get();
      final validDocs = _filterValidNotifications(query.docs);

      if (validDocs.isNotEmpty) {
        lastDoc = validDocs.last;

        // Load notifications immediately without translation
        final basicNotifications = _processNotificationsBasic(validDocs);
        final uniqueNotifications = _removeDuplicates(basicNotifications);

        if (mounted) {
          setState(() {
            notifications = uniqueNotifications;
            hasMore = query.docs.length == pageSize;
            isLoading = false;
          });
        }

        // NEW: Check cache and translate only if needed
        await _handleTranslations(validDocs, 0);
      } else {
        if (mounted) {
          setState(() {
            hasMore = false;
            notifications = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      log('Error loading notifications: $e');
      _showErrorSnackBar(
        AppLocalizations.of(context)!.errorLoadingNotifications,
      );
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (!hasMore || isLoadingMore || !mounted) return;
    setState(() => isLoadingMore = true);

    try {
      final query = await _getNotificationsQuery(startAfterDoc: lastDoc).get();
      final validDocs = _filterValidNotifications(query.docs);

      if (validDocs.isNotEmpty) {
        lastDoc = validDocs.last;

        final basicNotifications = _processNotificationsBasic(validDocs);
        final uniqueNotifications = _removeDuplicates(basicNotifications);

        if (mounted && uniqueNotifications.isNotEmpty) {
          final startIndex = notifications.length;
          setState(() {
            notifications.addAll(uniqueNotifications);
            hasMore = query.docs.length == pageSize;
            isLoadingMore = false;
          });

          // Handle translations for new notifications
          await _handleTranslations(validDocs, startIndex);
        } else {
          if (mounted) {
            setState(() {
              hasMore = query.docs.length == pageSize;
              isLoadingMore = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            hasMore = false;
            isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      log('Error loading more notifications: $e');
      _showErrorSnackBar(
        AppLocalizations.of(context)!.errorLoadingMoreNotifications,
      );
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  List<Map<String, dynamic>> _processNotificationsBasic(
    List<DocumentSnapshot> docs,
  ) {
    return docs.map((doc) {
      final data = Map<String, dynamic>.from(
        doc.data() as Map<String, dynamic>,
      );
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // NEW: Handle translations with cache checking
  Future<void> _handleTranslations(
    List<DocumentSnapshot> docs,
    int startIndex,
  ) async {
    try {
      // Initialize cache for current language if not exists
      _notificationCache[_currentLanguage] ??= {};

      // Separate cached and non-cached notifications
      final List<DocumentSnapshot> needTranslation = [];
      final List<int> needTranslationIndices = [];

      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final notificationIndex = startIndex + i;

        // Check if translation exists in cache
        final cachedTranslation = _notificationCache[_currentLanguage]![doc.id];

        if (cachedTranslation != null) {
          // Use cached translation
          log('Using cached translation for: ${doc.id}');
          if (mounted && notificationIndex < notifications.length) {
            setState(() {
              notifications[notificationIndex]['title'] =
                  cachedTranslation['title'] ??
                  notifications[notificationIndex]['title'];
              notifications[notificationIndex]['body'] =
                  cachedTranslation['body'] ??
                  notifications[notificationIndex]['body'];
            });
          }
        } else {
          // Need to translate
          needTranslation.add(doc);
          needTranslationIndices.add(notificationIndex);
        }
      }

      // Translate only non-cached notifications
      if (needTranslation.isNotEmpty) {
        log(
          'Translating ${needTranslation.length} notifications to $_currentLanguage',
        );
        await _translateAndCacheNotifications(
          needTranslation,
          needTranslationIndices,
        );
      }
    } catch (e) {
      log('Error in _handleTranslations: $e');
    }
  }

  // NEW: Translate and cache notifications
  Future<void> _translateAndCacheNotifications(
    List<DocumentSnapshot> docs,
    List<int> notificationIndices,
  ) async {
    try {
      // Collect texts to translate
      List<String> textsToTranslate = [];
      List<Map<String, dynamic>> translationMap = [];

      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title']?.toString().trim() ?? '';
        final body = data['body']?.toString().trim() ?? '';

        Map<String, dynamic> itemMap = {
          'docId': doc.id,
          'notificationIndex': notificationIndices[i],
          'originalTitle': title,
          'originalBody': body,
          'titleIndex': -1,
          'bodyIndex': -1,
        };

        // Add title to translation batch
        if (title.isNotEmpty) {
          itemMap['titleIndex'] = textsToTranslate.length;
          textsToTranslate.add(title);
        }

        // Add body to translation batch
        if (body.isNotEmpty) {
          itemMap['bodyIndex'] = textsToTranslate.length;
          textsToTranslate.add(body);
        }

        translationMap.add(itemMap);
      }

      // Batch translate all texts
      List<String> translatedTexts = [];
      if (textsToTranslate.isNotEmpty) {
        translatedTexts = await _batchTranslateTexts(
          textsToTranslate,
          _currentLanguage,
        );
      }

      // Update notifications and cache
      if (mounted && translatedTexts.isNotEmpty) {
        setState(() {
          for (final item in translationMap) {
            final notificationIndex = item['notificationIndex'] as int;
            final docId = item['docId'] as String;

            if (notificationIndex < notifications.length) {
              // Prepare cache entry
              final cacheEntry = <String, dynamic>{'timestamp': DateTime.now()};

              // Update title
              final titleIndex = item['titleIndex'] as int;
              if (titleIndex != -1 && titleIndex < translatedTexts.length) {
                final translatedTitle = translatedTexts[titleIndex];
                notifications[notificationIndex]['title'] = translatedTitle;
                cacheEntry['title'] = translatedTitle;
              } else {
                cacheEntry['title'] = item['originalTitle'];
              }

              // Update body
              final bodyIndex = item['bodyIndex'] as int;
              if (bodyIndex != -1 && bodyIndex < translatedTexts.length) {
                final translatedBody = translatedTexts[bodyIndex];
                notifications[notificationIndex]['body'] = translatedBody;
                cacheEntry['body'] = translatedBody;
              } else {
                cacheEntry['body'] = item['originalBody'];
              }

              // Store in cache
              _notificationCache[_currentLanguage]![docId] = cacheEntry;
              log('Cached translation for notification: $docId');
            }
          }
        });

        log(
          'Successfully cached ${translationMap.length} translations for $_currentLanguage',
        );
      }
    } catch (e) {
      log('Error in _translateAndCacheNotifications: $e');
    }
  }

  Future<List<String>> _batchTranslateTexts(
    List<String> texts,
    String targetLang,
  ) async {
    if (texts.isEmpty) return [];

    try {
      log('Making translation API call for ${texts.length} texts');
      final response = await http
          .post(
            Uri.parse(
              'https://translation.googleapis.com/language/translate/v2?key=$_apiKey',
            ),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'WorkerApp/1.0',
            },
            body: jsonEncode({
              'q': texts,
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
        throw Exception('Translation API error: ${response.statusCode}');
      }
    } catch (e) {
      log('Batch translation error: $e');
      rethrow;
    }

    return texts;
  }

  Query _getNotificationsQuery({DocumentSnapshot? startAfterDoc}) {
    Query query = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: LocalStoreHelper.getUID())
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }
    return query;
  }

  List<DocumentSnapshot> _filterValidNotifications(
    List<DocumentSnapshot> docs,
  ) {
    return docs.where((doc) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final title = data['title']?.toString().trim() ?? '';
        final body = data['body']?.toString().trim() ?? '';
        return title.isNotEmpty || body.isNotEmpty;
      } catch (e) {
        log('Error filtering notification ${doc.id}: $e');
        return false;
      }
    }).toList();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip:
                AppLocalizations.of(context)?.markAllAsRead ??
                'Mark All as Read',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPage,
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshPage,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount:
                    notifications.length + (hasMore && !isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == notifications.length) {
                    return _buildLoadMoreIndicator();
                  }

                  return _buildNotificationCard(notifications[index]);
                },
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingNotifications,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.loadingMore),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    try {
      final createdAt = notification['createdAt']?.toDate();
      final title = notification['title']?.toString().trim() ?? '';
      final body = notification['body']?.toString().trim() ?? '';
      final category = notification['category']?.toString() ?? 'general';
      // ✅ NEW: Check if notification is read
      final isRead = notification['isRead'] as bool? ?? false;

      if (title.isEmpty && body.isEmpty) {
        return const SizedBox.shrink();
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        // ✅ NEW: Grey background for read notifications
        color: isRead ? Colors.grey[100] : Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            // ✅ NEW: Greyed-out icon for read notifications
            backgroundColor: isRead ? Colors.grey[400] : AppColors.primary,
            child: Icon(_getNotificationIcon(category), color: Colors.white),
          ),
          title: title.isNotEmpty
              ? Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    // ✅ NEW: Greyed-out text for read notifications
                    color: isRead ? Colors.grey[500] : Colors.black,
                  ),
                )
              : null,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  // ✅ NEW: Greyed-out body text for read notifications
                  style: TextStyle(
                    color: isRead ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    // ✅ NEW: Lighter grey timestamp for read notifications
                    color: isRead ? Colors.grey[300] : Colors.grey[400],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      log('Error building notification card: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noNotificationsYet,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noNotificationsMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String category) {
    switch (category.toLowerCase()) {
      case 'booking':
        return Icons.event;
      case 'order':
        return Icons.shopping_cart;
      case 'service':
        return Icons.build;
      case 'payment':
        return Icons.payment;
      case 'account':
        return Icons.person;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }
}
