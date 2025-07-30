import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'app_services.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  await AppServices.storeNotificationInFirestore(message);
}

class NotificationServices {
  static bool _fcmPermissionRequested = false;
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> setupFCMListeners() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
      if (message.notification != null) {
        AppServices.storeNotificationInFirestore(message);
      }
    });
  }

  static Future<void> initializeFCM() async {
    if (_fcmPermissionRequested) return;
    _fcmPermissionRequested = true;
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? token;

        if (Platform.isIOS) {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            token = await _firebaseMessaging.getToken();
          } else {
            _firebaseMessaging.onTokenRefresh.listen((fcmToken) {
              if (fcmToken.isNotEmpty) {
                AppServices.updateFCMToken(fcmToken);
              }
            });
            return;
          }
        } else {
          token = await _firebaseMessaging.getToken();
        }

        if (token != null && token.isNotEmpty) {
          await AppServices.updateFCMToken(token);

          _firebaseMessaging.onTokenRefresh.listen((fcmToken) {
            AppServices.updateFCMToken(fcmToken);
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

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

  static Future<void> checkForInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();

    if (initialMessage != null) {
      if (initialMessage.notification != null) {
        AppServices.storeNotificationInFirestore(initialMessage);
      }
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        AppServices.storeNotificationInFirestore(message);
      }
    });
  }
}
