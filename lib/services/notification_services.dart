import 'dart:convert';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'app_services.dart';
import '../main.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Background message received: ${message.messageId}');

  // Set persistence in background isolate too (with try-catch)
  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (e) {
    // Already set, ignore
  }

  // Note: Notification is already stored by backend Cloud Function
  // No need to store it again here to avoid duplicates
}

class NotificationServices {
  static bool _isInitialized = false;
  static bool _tokenRefreshListenerSet = false;
  static bool _isRequestingPermission = false; // Prevent duplicate requests

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  /// Track if the tracking notification has already alerted the user
  static bool _hasAlertedTracking = false;
  
  /// Track the current active chat to suppress notifications when user is inside the chat
  static String? currentActiveChatId;

  /// Set the current active chat ID
  static void setActiveChatId(String? chatId) {
    currentActiveChatId = chatId;
    debugPrint('🔔 Active chat set to: $chatId');
  }

  /// Initialize local notifications
  static Future<void> initializeNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: false, // We'll request manually
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('👆 Notification tapped: ${response.payload}');
          _handleNotificationTap(response.payload);
        },
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      // 1. General channel
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'abo_glumbo_channel',
          'Abo Glumbo Notifications',
          description: 'Notifications related to Abo Glumbo tasks and updates',
          importance: Importance.max,
        ),
      );

      // 2. Tracking channel (Ongoing/Persistent but SILENT)
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'abo_glumbo_tracking_silent', // Silent channel
          'Live Tracking updates',
          description: 'Background updates for live tracking',
          importance: Importance.low, 
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );

      // 3. Tracking alert channel (High priority for the FIRST alert)
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'abo_glumbo_tracking_alert', // Alert channel
          'Live Tracking Alert',
          description: 'Initial alert for live tracking',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  /// Setup FCM listeners with duplicate request prevention
  static Future<void> setupFCMListeners() async {
    // Prevent duplicate permission requests
    if (_isRequestingPermission) {
      debugPrint('⚠️ Permission request already in progress, skipping...');
      return;
    }

    if (_isInitialized) {
      debugPrint('⚠️ FCM already initialized, skipping...');
      return;
    }

    try {
      _isRequestingPermission = true;

      // Set foreground notification options
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Request permission
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ FCM permission granted');

        // Get FCM token
        await _getFCMTokenAndUpdate();

        // Setup token refresh listener
        _setupTokenRefreshListener();

        // Setup message handlers
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📨 Foreground message received: ${message.messageId}');
          
          final data = message.data;
          final String? incomingChatId = data['chatId']?.toString();
          
          // Suppress notification if user is already in this chat
          if (incomingChatId != null && incomingChatId == currentActiveChatId) {
            debugPrint('🤫 Suppressing foreground notification for active chat: $incomingChatId');
            return;
          }

          RemoteNotification? notification = message.notification;
          if (notification != null && Platform.isAndroid) {
            showNotification(
              id: notification.hashCode,
              title: notification.title ?? 'Notification',
              body: notification.body ?? '',
              payload: json.encode(message.data),
            );
          }
        });

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('👆 Message opened from background: ${message.messageId}');
          if (message.notification != null) {
            // Only handle chat navigation, do NOT store notification again
            _handleChatNotificationTap(message);
          }
        });

        _isInitialized = true;
        debugPrint('✅ FCM listeners setup complete');
      } else {
        debugPrint('❌ FCM permission denied');
      }
    } catch (e) {
      debugPrint('❌ Error setting up FCM: $e');

      // Handle "already running" error gracefully
      if (e.toString().contains('already running')) {
        debugPrint(
          '⚠️ Permission request already running - marking as initialized',
        );
        _isInitialized = true;
      }
    } finally {
      _isRequestingPermission = false;
    }
  }

  /// Get FCM token and update in Firestore
  static Future<void> _getFCMTokenAndUpdate() async {
    try {
      String? token;

      if (Platform.isIOS) {
        // Wait for APNS token with timeout on iOS
        await _waitForAPNSToken();
        token = await _firebaseMessaging.getToken();
      } else {
        token = await _firebaseMessaging.getToken();
      }

      if (token != null && token.isNotEmpty) {
        debugPrint('🔑 FCM Token: ${token.substring(0, 20)}...');
        await AppServices.updateFCMToken(token);
      } else {
        debugPrint('⚠️ No FCM token available');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Wait for APNS token on iOS
  static Future<void> _waitForAPNSToken() async {
    try {
      String? apnsToken = await _firebaseMessaging.getAPNSToken();
      int attempts = 0;

      while (apnsToken == null && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 500));
        apnsToken = await _firebaseMessaging.getAPNSToken();
        attempts++;
      }

      if (apnsToken != null) {
        debugPrint('✅ APNS token obtained');
      } else {
        debugPrint('⚠️ APNS token not available after 10 seconds');
      }
    } catch (e) {
      debugPrint('❌ Error waiting for APNS token: $e');
    }
  }

  /// Setup token refresh listener
  static void _setupTokenRefreshListener() {
    if (_tokenRefreshListenerSet) {
      debugPrint('⚠️ Token refresh listener already set');
      return;
    }

    _firebaseMessaging.onTokenRefresh.listen(
      (fcmToken) {
        if (fcmToken.isNotEmpty) {
          debugPrint('🔄 FCM Token refreshed: ${fcmToken.substring(0, 20)}...');
          AppServices.updateFCMToken(fcmToken)
              .then((_) {
                debugPrint('✅ Refreshed FCM Token updated successfully');
              })
              .catchError((error) {
                debugPrint('❌ Error updating refreshed FCM token: $error');
              });
        }
      },
      onError: (error) {
        debugPrint('❌ Error in token refresh listener: $error');
      },
    );

    _tokenRefreshListenerSet = true;
    debugPrint('✅ Token refresh listener set up');
  }

  /// Manually refresh FCM token (use sparingly)
  static Future<void> refreshFCMToken() async {
    if (_isRequestingPermission) {
      debugPrint('⚠️ Cannot refresh token - permission request in progress');
      return;
    }

    try {
      debugPrint('🔄 Manually refreshing FCM token...');
      await _firebaseMessaging.deleteToken();
      await Future.delayed(const Duration(milliseconds: 500));
      await _getFCMTokenAndUpdate();
    } catch (e) {
      debugPrint('❌ Error manually refreshing FCM token: $e');
    }
  }

  /// Get current FCM token
  static Future<String?> getCurrentFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('🔑 Current FCM Token: ${token.substring(0, 20)}...');
      } else {
        debugPrint('❌ No FCM token available');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error getting current FCM token: $e');
      return null;
    }
  }

  /// Delete FCM token
  static Future<void> deleteFCMToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _isInitialized = false; // Reset so FCM can be re-initialized
      debugPrint('🗑️ FCM token deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Debug FCM status
  static Future<void> debugFCMStatus() async {
    try {
      debugPrint('🔍 FCM Debug Status:');
      debugPrint('   - Initialized: $_isInitialized');
      debugPrint('   - Token refresh listener set: $_tokenRefreshListenerSet');
      debugPrint('   - Requesting permission: $_isRequestingPermission');

      String? token = await getCurrentFCMToken();
      if (token != null) {
        debugPrint('   - Current token available: Yes');
        debugPrint('   - Token length: ${token.length}');
      } else {
        debugPrint('   - Current token available: No');
      }

      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        debugPrint(
          '   - APNS Token available: ${apnsToken != null ? "Yes" : "No"}',
        );
      }

      NotificationSettings settings = await _firebaseMessaging
          .getNotificationSettings();
      debugPrint('   - Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('❌ Error getting FCM debug status: $e');
    }
  }

  /// Show local notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'abo_glumbo_channel',
      'Abo Glumbo Notifications',
      channelDescription:
          'Notifications related to Abo Glumbo tasks and updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      visibility: NotificationVisibility.public,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      ),
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Show ongoing tracking notification (non-dismissable)
  /// This notification will persist in the notification bar while tracking is active
  static Future<void> showOngoingTrackingNotification({
    String title = 'Tracking Active',
    String? serviceName,
    String body = 'Tracking your technician\'s live location',
    int? etaMinutes,
    String? etaTime,
    String? bookingId,
  }) async {
    const int trackingNotificationId = 9999; // Use a fixed ID for tracking

    // Build notification title with service name if available
    String notificationTitle = title;
    if (serviceName != null && serviceName.isNotEmpty) {
      notificationTitle = '$title - $serviceName';
    }

    // Build notification body with ETA if available
    String notificationBody = body;
    if (etaMinutes != null && etaMinutes >= 0) {
      notificationBody = '$body\nETA: $etaMinutes min';
      if (etaTime != null) {
        notificationBody += ' (${etaTime.substring(0, 5)})';
      }
    }

    // Create JSON payload with booking ID
    String? payload;
    if (bookingId != null && bookingId.isNotEmpty) {
      payload = jsonEncode({'type': 'tracking', 'bookingId': bookingId});
    }

    // Use Alert channel for first time, Silent channel thereafter
    final String channelId = _hasAlertedTracking 
        ? 'abo_glumbo_tracking_silent' 
        : 'abo_glumbo_tracking_alert';
    
    // Set importance based on channel
    final Importance importance = _hasAlertedTracking ? Importance.low : Importance.high;
    final Priority priority = _hasAlertedTracking ? Priority.low : Priority.high;

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _hasAlertedTracking ? 'Live Tracking updates' : 'Live Tracking Alert',
      channelDescription: _hasAlertedTracking ? 'Background updates' : 'Initial alert',
      importance: importance,
      priority: priority,
      ongoing: true, // Non-dismissible
      autoCancel: false,
      onlyAlertOnce: true,
      color: const Color(0xFF4CAF50),
      colorized: true,
      showWhen: true,
      usesChronometer: false,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.service,
      enableVibration: !_hasAlertedTracking,
      playSound: !_hasAlertedTracking,
      enableLights: !_hasAlertedTracking,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        notificationBody,
        contentTitle: notificationTitle,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      ),
    );

    // After first time, set flag to true so next updates are silent
    if (!_hasAlertedTracking) {
      _hasAlertedTracking = true;
    }

    final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: !_hasAlertedTracking,
      presentBadge: false,
      presentSound: !_hasAlertedTracking,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      trackingNotificationId,
      notificationTitle,
      notificationBody,
      platformDetails,
      payload: payload,
    );

    debugPrint('✅ Ongoing tracking notification shown');
  }

  /// Cancel ongoing tracking notification
  static Future<void> cancelTrackingNotification() async {
    const int trackingNotificationId = 9999;

    try {
      await _flutterLocalNotificationsPlugin.cancel(trackingNotificationId);
      _hasAlertedTracking = false; // Reset flag so next session alerts again
      debugPrint('✅ Tracking notification cancelled and state reset');
    } catch (e) {
      debugPrint('❌ Error cancelling tracking notification: $e');
    }
  }

  /// Check for initial message (app opened from terminated state)
  static Future<void> checkForInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();

      if (initialMessage != null) {
        debugPrint('📬 Initial message found: ${initialMessage.messageId}');
        if (initialMessage.notification != null) {
          // Only handle chat navigation, do NOT store notification again
          _handleChatNotificationTap(initialMessage);
        }
      }

      // Note: onMessageOpenedApp listener is already set up in setupFCMListeners()
      // No need to add it here again to avoid duplicate navigation
    } catch (e) {
      debugPrint('❌ Error checking initial message: $e');
    }
  }

  /// Handle notification tap and navigate accordingly
  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) {
      debugPrint('⚠️ No payload in notification');
      return;
    }

    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      debugPrint('📱 Full notification payload: $data');

      final type = data['type'] as String?;
      final chatId = data['chatId'] as String?;
      final bookingId = data['bookingId'] as String?;

      debugPrint(
        '📱 Notification type: $type, chatId: $chatId, bookingId: $bookingId',
      );

      // Check if this is a tracking notification
      if (type == 'tracking' && bookingId != null && bookingId.isNotEmpty) {
        debugPrint('📍 Tracking notification detected!');
        debugPrint('   bookingId: $bookingId');
        _handleTrackingNotificationTap(bookingId);
      }
      // Check if this is a chat notification (either by type or presence of chatId)
      else if (type == 'chat' || (chatId != null && chatId.isNotEmpty)) {
        // Extract chat data from payload
        final participantName =
            data['participantName'] as String? ?? 'Technician';
        final participantId = data['participantId'] as String? ?? '';
        final participantPhoto = data['participantPhoto'] as String? ?? '';
        final customerName = data['customerName'] as String? ?? '';
        final customerPhoto = data['customerPhoto'] as String? ?? '';
        final bookingId = data['bookingId'] as String? ?? '';

        debugPrint('💬 Chat notification detected!');
        debugPrint('   chatId: $chatId');
        debugPrint('   participantName: $participantName');
        debugPrint('   participantId: $participantId');

        if (chatId != null && chatId.isNotEmpty) {
          debugPrint('🚀 Starting navigation to chat screen...');

          // Use the global navigator key to navigate
          if (navigatorKey?.currentState != null) {
            debugPrint('✅ Navigator is available');

            // Clear stack and set up: Home -> ChatScreen
            // This ensures back button from chat goes directly to home
            navigatorKey!.currentState!.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const Home()),
              (route) => false,
            );

            // Immediately push chat screen on top of home
            navigatorKey!.currentState!
                .push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: chatId,
                      participantName: participantName,
                      participantId: participantId,
                      participantPhoto: participantPhoto,
                      customerName: customerName,
                      customerPhoto: customerPhoto,
                      bookingId: bookingId,
                    ),
                  ),
                )
                .then((_) {
                  debugPrint('✅ Chat screen navigation completed');
                })
                .catchError((error) {
                  debugPrint('❌ Error pushing chat screen: $error');
                });
          } else {
            debugPrint('⚠️ Navigator key is null, cannot navigate');
          }
        } else {
          debugPrint('⚠️ Chat ID is missing in notification payload');
        }
      } else {
        debugPrint('ℹ️ Not a recognized notification type, ignoring');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  /// Handle tracking notification tap - navigate to live tracking
  static void _handleTrackingNotificationTap(String bookingId) {
    try {
      debugPrint(
        '🚀 Starting navigation to tracking page for booking: $bookingId',
      );

      // Use the global navigator key to navigate
      if (navigatorKey?.currentState != null) {
        debugPrint('✅ Navigator is available for tracking navigation');

        // Navigate to Home which will display ActiveBookingsSection
        navigatorKey!.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Home()),
          (route) => false,
        );

        debugPrint('✅ Navigated to Home to show live tracking');
      } else {
        debugPrint('⚠️ Navigator key is null, cannot navigate to tracking');
      }
    } catch (e) {
      debugPrint('❌ Error handling tracking notification tap: $e');
    }
  }

  /// Handle chat notification tap (extracted for reusability)
  static void _handleChatNotificationTap(RemoteMessage message) {
    try {
      final data = message.data;
      debugPrint('📱 Chat notification data: $data');

      final chatId = data['chatId'] as String?;
      final participantName =
          data['participantName'] as String? ?? 'Technician';
      final participantId = data['participantId'] as String? ?? '';
      final participantPhoto = data['participantPhoto'] as String? ?? '';
      final customerName = data['customerName'] as String? ?? '';
      final customerPhoto = data['customerPhoto'] as String? ?? '';
      final bookingId = data['bookingId'] as String? ?? '';

      debugPrint('💬 Navigating to chat screen...');
      debugPrint('   chatId: $chatId');
      debugPrint('   participantName: $participantName');
      debugPrint('   participantId: $participantId');

      if (chatId != null && chatId.isNotEmpty) {
        // Use the global navigator key to navigate
        if (navigatorKey?.currentState != null) {
          debugPrint('✅ Navigator is available');

          // Clear stack and set up: Home -> ChatScreen
          // This ensures back button from chat goes directly to home
          navigatorKey!.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );

          // Immediately push chat screen on top of home
          navigatorKey!.currentState!
              .push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chatId,
                    participantName: participantName,
                    participantId: participantId,
                    participantPhoto: participantPhoto,
                    customerName: customerName,
                    customerPhoto: customerPhoto,
                    bookingId: bookingId,
                  ),
                ),
              )
              .then((_) {
                debugPrint('✅ Chat screen navigation completed');
              })
              .catchError((error) {
                debugPrint('❌ Error pushing chat screen: $error');
              });
        } else {
          debugPrint('⚠️ Navigator key is null, cannot navigate');
        }
      } else {
        debugPrint('⚠️ Chat ID is missing in notification payload');
      }
    } catch (e) {
      debugPrint('❌ Error handling chat notification tap: $e');
    }
  }

  /// Initialize FCM (legacy method - keeping for compatibility)
  static Future<void> initializeFCM() async {
    try {
      await setupFCMListeners();
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
    }
  }

  /// Cache of triggered local notifications to prevent spamming
  /// Structure: { bookingId: { 'on_the_way': true, '10_minutes': true, ... } }
  static final Map<String, Map<String, bool>> _triggeredLocalNotifications = {};

  /// Check if a local notification has already been triggered for a booking
  static bool hasTriggeredLocalNotification(String bookingId, String type) {
    return _triggeredLocalNotifications[bookingId]?[type] ?? false;
  }

  /// Mark a local notification as triggered for a booking
  static void markLocalNotificationTriggered(String bookingId, String type) {
    if (!_triggeredLocalNotifications.containsKey(bookingId)) {
      _triggeredLocalNotifications[bookingId] = {};
    }
    _triggeredLocalNotifications[bookingId]![type] = true;
    debugPrint('🔔 Marked tracking notification $type as triggered for $bookingId');
  }

  /// Clear the local notification triggers for a booking (e.g. when tracking stops/resets)
  static void clearLocalNotificationTriggers(String bookingId) {
    _triggeredLocalNotifications.remove(bookingId);
    debugPrint('🗑️ Cleared tracking notification flags for $bookingId');
  }

  /// Display local live tracking notifications for the customer in multiple languages
  static Future<void> showLocalLiveTrackingNotification({
    required String type, // 'on_the_way', '10_minutes', 'nearby', 'arrived'
    required String bookingId,
    required String technicianName,
  }) async {
    final languageCode = LocalStoreHelper.getUserlanguage();
    
    String title = '';
    String body = '';
    
    if (languageCode == 'ar') {
      switch (type) {
        case 'on_the_way':
          title = 'الفني في الطريق';
          body = 'الفني $technicianName في طريقه إلى موقعك.';
          break;
        case '10_minutes':
          title = 'الفني على بعد 10 دقائق';
          body = 'سيصل الفني $technicianName خلال 10 دقائق.';
          break;
        case 'nearby':
          title = 'الفني قريب منك';
          body = 'الفني $technicianName على بعد أقل من 5 دقائق.';
          break;
        case 'arrived':
          title = 'وصل الفني';
          body = 'وصل الفني $technicianName إلى موقعك.';
          break;
      }
    } else if (languageCode == 'ur') {
      switch (type) {
        case 'on_the_way':
          title = 'ٹیکنیشن راستے میں ہے';
          body = 'آپ کا ٹیکنیشن $technicianName آپ کے مقام پر آ رہا ہے۔';
          break;
        case '10_minutes':
          title = 'ٹیکنیشن 10 منٹ کی دوری پر ہے';
          body = 'آپ کا ٹیکنیشن $technicianName 10 منٹ میں پہنچ جائے گا۔';
          break;
        case 'nearby':
          title = 'ٹیکنیشن قریب ہی ہے';
          body = 'آپ کا ٹیکنیشن $technicianName 5 منٹ سے भी कम وقت میں پہنچ رہا ہے۔';
          break;
        case 'arrived':
          title = 'ٹیکنیشن پہنچ گیا ہے';
          body = 'آپ کا ٹیکنیشن $technicianName آپ کے مقام پر پہنچ گیا ہے۔';
          break;
      }
    } else {
      // Default to English
      switch (type) {
        case 'on_the_way':
          title = 'Technician is on the way';
          body = 'Your technician $technicianName is on the way to your location.';
          break;
        case '10_minutes':
          title = 'Technician is 10 minutes away';
          body = 'Your technician $technicianName will arrive in 10 minutes.';
          break;
        case 'nearby':
          title = 'Technician is nearby';
          body = 'Your technician $technicianName is less than 5 minutes away.';
          break;
        case 'arrived':
          title = 'Technician Arrived';
          body = 'Your technician $technicianName has arrived at your location.';
          break;
      }
    }

    if (title.isEmpty || body.isEmpty) return;

    // Use a unique notification ID per booking + type combination to avoid collision
    final int notificationId = (bookingId.hashCode + type.hashCode).abs();

    await showNotification(
      id: notificationId,
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'tracking_update',
        'bookingId': bookingId,
        'trackingType': type,
      }),
    );
    debugPrint('🔔 Local live tracking notification shown: $title - $body');
  }

  /// Parse a duration string (e.g. "10 mins") into an integer representing minutes
  static int extractMinutesFromDuration(String duration) {
    if (duration.isEmpty) return 15;

    // Clean the input string
    final cleanDuration = duration.toLowerCase().trim();

    // Pattern 1: Simple formats like "15 min", "30 mins", "5 minutes"
    final RegExp simpleMinRegex = RegExp(r'(\d+)\s*(?:min|minute)s?\b');
    final simpleMatch = simpleMinRegex.firstMatch(cleanDuration);
    if (simpleMatch != null) {
      final minutes = int.tryParse(simpleMatch.group(1) ?? '0') ?? 0;
      return minutes > 0 ? minutes : 15;
    }

    // Pattern 2: Hour formats like "1 hour", "2 hrs", "1.5 hours"
    final RegExp hourOnlyRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr)s?\b');
    final hourOnlyMatch = hourOnlyRegex.firstMatch(cleanDuration);
    if (hourOnlyMatch != null &&
        !cleanDuration.contains(RegExp(r'\d+\s*(?:min|minute)'))) {
      final hoursStr = hourOnlyMatch.group(1) ?? '0';
      final hours = double.tryParse(hoursStr) ?? 0.0;
      final minutes = (hours * 60).round();
      return minutes > 0 ? minutes : 15;
    }

    // Pattern 3: Complex formats like "1 hour 30 mins", "2 hrs 45 minutes"
    final RegExp hourRegex = RegExp(r'(\d+)\s*(?:hour|hr)s?');
    final RegExp minRegex = RegExp(r'(\d+)\s*(?:min|minute)s?');

    final hourMatch = hourRegex.firstMatch(cleanDuration);
    final minMatch = minRegex.firstMatch(cleanDuration);

    int totalMinutes = 0;

    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '0') ?? 0;
      totalMinutes += hours * 60;
    }

    if (minMatch != null) {
      final minutes = int.tryParse(minMatch.group(1) ?? '0') ?? 0;
      totalMinutes += minutes;
    }

    // Pattern 4: Just numbers (assume minutes)
    if (totalMinutes == 0) {
      final RegExp numberRegex = RegExp(r'(\d+)');
      final numberMatch = numberRegex.firstMatch(cleanDuration);
      if (numberMatch != null) {
        totalMinutes = int.tryParse(numberMatch.group(1) ?? '0') ?? 0;
      }
    }

    // Fallback to 15 minutes if no valid duration found
    return totalMinutes > 0 ? totalMinutes : 15;
  }
}
