import 'dart:convert';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
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

  await AppServices.storeNotificationInFirestore(message);
}

class NotificationServices {
  static bool _isInitialized = false;
  static bool _tokenRefreshListenerSet = false;
  static bool _isRequestingPermission = false; // Prevent duplicate requests

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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
          RemoteNotification? notification = message.notification;
          if (notification != null) {
            showNotification(
              id: notification.hashCode,
              title: notification.title ?? 'Notification',
              body: notification.body ?? '',
              payload: json.encode(message.data),
            );
            AppServices.storeNotificationInFirestore(message);
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
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const NotificationDetails platformDetails = NotificationDetails(
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

      debugPrint('📱 Notification type: $type, chatId: $chatId');

      // Check if this is a chat notification (either by type or presence of chatId)
      if (type == 'chat' || (chatId != null && chatId.isNotEmpty)) {
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
        debugPrint('ℹ️ Not a chat notification, ignoring');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
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
}
