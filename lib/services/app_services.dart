import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class AppServices {
  static String uid = LocalStoreHelper.getUID() ?? '';
  static Future<void> storeNotificationInFirestore(
    RemoteMessage message,
  ) async {
    try {
      Map<String, dynamic> notificationData = {
        'userId': uid,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'messageId': message.messageId,
        'sentTime': message.sentTime,
        'createdAt': Timestamp.now(),
        'isRead': false,
        'category': message.data['category'] ?? 'general',
        'action': message.data['action'] ?? '',
        'platform': message.data['platform'] ?? 'unknown',
      };
      await AppFirestore.notificationsCollectionRef.add(notificationData);
    } catch (e) {
      debugPrint('❌ Error storing notification in Firestore: $e');
    }
  }

  static Future<void> updateFCMToken(String token) async {
    try {
      await AppFirestore.customersCollectionRef.doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }
}
