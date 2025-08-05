import 'dart:developer';
import 'dart:convert';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
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

  // Translation system with caching
  String _currentLanguage = 'en';
  final String _apiKey = 'AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o';
  final Map<String, String> _translationCache = {}; // Cache translations

  // NEW: Set to track unique notifications (title + datetime)
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
      // Clear cache when language changes
      _translationCache.clear();
      if (notifications.isNotEmpty) {
        _refreshNotifications();
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _loadInitialNotifications();
    } catch (e) {
      log('Error initializing app: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      lastDoc = null;
      hasMore = true;
      // NEW: Clear the unique keys set when refreshing
      _notificationKeys.clear();
      setState(() {
        notifications = [];
        isLoading = true;
      });
      await _loadInitialNotifications();
    } catch (e) {
      log('Error refreshing notifications: $e');
      _showErrorSnackBar(
        AppLocalizations.of(context)!.errorRefreshingNotifications,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      _loadMoreNotifications();
    }
  }

  // NEW: Create unique key for notification (title + formatted datetime)
  String _createNotificationKey(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim() ?? '';
    final createdAt = data['createdAt']?.toDate();

    if (title.isEmpty || createdAt == null) {
      // For notifications without title or date, use document ID to avoid false duplicates
      return data['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
    }

    // Create key with title and formatted datetime
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
    return '${title}_$dateStr';
  }

  // NEW: Remove duplicates from notifications list
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

    // Update the global set
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

        // OPTIMIZATION 1: Load notifications immediately without translation
        final basicNotifications = _processNotificationsBasic(validDocs);

        // NEW: Remove duplicates before showing
        final uniqueNotifications = _removeDuplicates(basicNotifications);

        if (mounted) {
          setState(() {
            notifications = uniqueNotifications;
            hasMore = query.docs.length == pageSize;
            isLoading = false; // Show content immediately
          });
        }

        // OPTIMIZATION 2: Translate in background after showing content
        _translateNotificationsInBackground(validDocs);
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

        // Load basic notifications first
        final basicNotifications = _processNotificationsBasic(validDocs);

        // NEW: Remove duplicates before adding to existing list
        final uniqueNotifications = _removeDuplicates(basicNotifications);

        if (mounted && uniqueNotifications.isNotEmpty) {
          setState(() {
            notifications.addAll(uniqueNotifications);
            hasMore = query.docs.length == pageSize;
            isLoadingMore = false;
          });

          // Translate in background
          _translateNotificationsInBackground(
            validDocs,
            startIndex: notifications.length - uniqueNotifications.length,
          );
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

  // OPTIMIZATION 3: Process notifications without translation first
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

  // OPTIMIZATION 4: Background translation with batch processing and caching
  Future<void> _translateNotificationsInBackground(
    List<DocumentSnapshot> docs, {
    int startIndex = 0,
  }) async {
    try {
      // Collect all texts that need translation
      List<String> textsToTranslate = [];
      List<Map<String, dynamic>> translationMap = [];

      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title']?.toString().trim() ?? '';
        final body = data['body']?.toString().trim() ?? '';

        Map<String, dynamic> itemMap = {
          'docIndex': i,
          'originalTitle': title,
          'originalBody': body,
          'titleIndex': -1,
          'bodyIndex': -1,
        };

        // Add title to translation batch if not cached
        if (title.isNotEmpty) {
          final cacheKey = '${title}_$_currentLanguage';
          if (!_translationCache.containsKey(cacheKey)) {
            itemMap['titleIndex'] = textsToTranslate.length;
            textsToTranslate.add(title);
          }
        }

        // Add body to translation batch if not cached
        if (body.isNotEmpty) {
          final cacheKey = '${body}_$_currentLanguage';
          if (!_translationCache.containsKey(cacheKey)) {
            itemMap['bodyIndex'] = textsToTranslate.length;
            textsToTranslate.add(body);
          }
        }

        translationMap.add(itemMap);
      }

      // OPTIMIZATION 5: Batch translate all texts at once
      List<String> translatedTexts = [];
      if (textsToTranslate.isNotEmpty) {
        translatedTexts = await _batchTranslateTexts(
          textsToTranslate,
          _currentLanguage,
        );
      }

      // Update notifications with translations
      if (mounted && translatedTexts.isNotEmpty) {
        setState(() {
          for (int i = 0; i < translationMap.length; i++) {
            final item = translationMap[i];
            final notificationIndex = startIndex + (item['docIndex'] as int);

            if (notificationIndex < notifications.length) {
              // Update title
              final titleIndex = item['titleIndex'] as int;
              if (titleIndex != -1) {
                final translatedTitle = translatedTexts[titleIndex];
                notifications[notificationIndex]['title'] = translatedTitle;
                // Cache the translation
                _translationCache['${item['originalTitle']}_$_currentLanguage'] =
                    translatedTitle;
              } else if ((item['originalTitle'] as String).isNotEmpty) {
                // Use cached translation
                final cacheKey = '${item['originalTitle']}_$_currentLanguage';
                notifications[notificationIndex]['title'] =
                    _translationCache[cacheKey] ?? item['originalTitle'];
              }

              // Update body
              final bodyIndex = item['bodyIndex'] as int;
              if (bodyIndex != -1) {
                final translatedBody = translatedTexts[bodyIndex];
                notifications[notificationIndex]['body'] = translatedBody;
                // Cache the translation
                _translationCache['${item['originalBody']}_$_currentLanguage'] =
                    translatedBody;
              } else if ((item['originalBody'] as String).isNotEmpty) {
                // Use cached translation
                final cacheKey = '${item['originalBody']}_$_currentLanguage';
                notifications[notificationIndex]['body'] =
                    _translationCache[cacheKey] ?? item['originalBody'];
              }
            }
          }
        });
      }
    } catch (e) {
      log('Error in background translation: $e');
      // Silently fail - users already see the original content
    }
  }

  // OPTIMIZATION 6: Batch translation API call
  Future<List<String>> _batchTranslateTexts(
    List<String> texts,
    String targetLang,
  ) async {
    if (texts.isEmpty) return [];

    try {
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
              'q': texts, // Send all texts at once
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

    return texts; // Return original texts on error
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshNotifications,
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

      // Skip empty notifications
      if (title.isEmpty && body.isEmpty) {
        return const SizedBox.shrink();
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Icon(_getNotificationIcon(category), color: Colors.white),
          ),
          title: title.isNotEmpty
              ? Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                )
              : null,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: Colors.grey[700])),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
