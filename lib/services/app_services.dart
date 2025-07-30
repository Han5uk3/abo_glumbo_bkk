import 'dart:developer';

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/banner.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
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

  static Future<CustomerModel> fetchCustomerData({required String uid}) async {
    try {
      DocumentSnapshot doc = await AppFirestore.customersCollectionRef
          .doc(uid)
          .get();
      if (doc.exists) {
        return CustomerModel.fromJson(doc.data() as Map<String, dynamic>);
      } else {
        throw Exception('Customer data not found for UID: $uid');
      }
    } catch (e) {
      debugPrint('❌ Error fetching customer data: $e');
      rethrow;
    }
  }

  static Stream<CustomerModel> listenToCustomerData(String uid) {
    return AppFirestore.customersCollectionRef.doc(uid).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return CustomerModel.fromJson(snapshot.data() as Map<String, dynamic>);
      } else {
        throw Exception('Customer data not found for UID: $uid');
      }
    });
  }

  static Future<void> updateNotificationLanguage(String lanCode) async {
    try {
      await AppFirestore.customersCollectionRef.doc(uid).update({
        'lanCode': lanCode,
      });
    } catch (e) {
      debugPrint('❌ Error updating notification language: $e');
    }
  }

  static Stream<List<ServiceModel>> listenToWishlist() {
    return AppFirestore.customersCollectionRef.doc(uid).snapshots().asyncMap((
      customerSnapshot,
    ) async {
      try {
        final customerData = customerSnapshot.data() as Map<String, dynamic>?;
        log(customerData.toString());
        final favourites = List<String>.from(customerData?['favourites'] ?? []);

        if (favourites.isEmpty) {
          return <ServiceModel>[];
        }

        final requestList = favourites
            .map(
              (serviceId) =>
                  AppFirestore.servicesCollectionRef.doc(serviceId).get(),
            )
            .toList();

        final responses = await Future.wait(requestList);

        return responses
            .where((doc) => doc.exists)
            .map((doc) => ServiceModel.fromDocumentSnapshot(doc))
            .toList();
      } catch (e) {
        print('Error loading wishlist: $e');
        return <ServiceModel>[];
      }
    });
  }

  static Future<void> removeFromWishlist(String serviceId) async {
    try {
      await AppFirestore.customersCollectionRef.doc(uid).update({
        'favourites': FieldValue.arrayRemove([serviceId]),
      });
    } catch (e) {
      debugPrint('❌ Error removing from wishlist: $e');
    }
  }

  static Future<CustomerModel> updateCustomerProfile({
    required CustomerModel customerData,
  }) async {
    try {
      await AppFirestore.customersCollectionRef
          .doc(uid)
          .update(customerData.toJson());
      return customerData;
    } catch (e) {
      debugPrint('❌ Error updating customer profile: $e');
      rethrow;
    }
  }

  static Future<List<LocationModel>> fetchLocations() async {
    try {
      final snapshot = await AppFirestore.locationsCollectionRef.get();
      return snapshot.docs
          .map(
            (doc) => LocationModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching locations: $e');
      return [];
    }
  }

  static Stream<List<CategoryModel>> listenToCategories() {
    return AppFirestore.categoriesCollectionRef
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    CategoryModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  static Future<List<BannerModel>> fetchBanners() async {
    try {
      final snapshot = await AppFirestore.bannersCollectionRef
          .where('active', isEqualTo: true)
          .get();
      return snapshot.docs
          .map(
            (doc) => BannerModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching banners: $e');
      return [];
    }
  }

  static Future<void> updateCustomerLocation(String userLocation) async {
    try {
      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(uid)
          .get();
      final existingData = docSnapshot.data() as Map<String, dynamic>?;
      final existingLocation =
          existingData?['location'] as Map<String, dynamic>?;

      await AppFirestore.customersCollectionRef.doc(uid).set({
        'location': {
          'name': userLocation.isNotEmpty
              ? userLocation
              : existingLocation?['name'] ?? '',
          'name_ar': userLocation.isNotEmpty
              ? userLocation
              : existingLocation?['name_ar'] ?? '',
          'lat': existingLocation?['lat'],
          'lon': existingLocation?['lon'],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating customer location: $e');
    }
  }

  static Future<void> updateCustomerLonAndLat(
    double longitude,
    double latitude,
  ) async {
    try {
      await AppFirestore.customersCollectionRef.doc(uid).update({
        'location': {'lon': longitude, 'lat': latitude},
      });
    } catch (e) {
      debugPrint('❌ Error updating customer longitude and latitude: $e');
    }
  }
}
