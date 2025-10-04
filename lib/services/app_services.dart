import 'dart:developer';

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/banner.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/faq.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class AppServices {
  static String uid = LocalStoreHelper.getUID() ?? '';

  // Method to refresh the UID when needed
  static void refreshUID() {
    uid = LocalStoreHelper.getUID() ?? '';
  }

  static Future<void> storeNotificationInFirestore(
    RemoteMessage message,
  ) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot store notification: User ID is empty');
        return;
      }

      Map<String, dynamic> notificationData = {
        'userId': currentUid,
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
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot update FCM token: User ID is empty');
        return;
      }

      debugPrint('📤 Updating FCM token for user: $currentUid');
      debugPrint('🔑 Token: ${token.substring(0, 20)}...');

      await AppFirestore.customersCollectionRef.doc(currentUid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': Timestamp.now(),
      });

      debugPrint('✅ FCM token updated successfully in Firestore');
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');

      // Try to create the document if it doesn't exist
      try {
        String currentUid = LocalStoreHelper.getUID() ?? '';
        await AppFirestore.customersCollectionRef.doc(currentUid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token set successfully with merge option');
      } catch (setError) {
        debugPrint('❌ Error setting FCM token with merge: $setError');
      }
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
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot update notification language: User ID is empty');
        return;
      }

      await AppFirestore.customersCollectionRef.doc(currentUid).update({
        'lanCode': lanCode,
      });
    } catch (e) {
      debugPrint('❌ Error updating notification language: $e');
    }
  }

  static Stream<List<ServiceModel>> listenToWishlist() {
    String currentUid = LocalStoreHelper.getUID() ?? '';
    if (currentUid.isEmpty) {
      debugPrint('❌ Cannot listen to wishlist: User ID is empty');
      return Stream.value(<ServiceModel>[]);
    }

    return AppFirestore.customersCollectionRef
        .doc(currentUid)
        .snapshots()
        .asyncMap((customerSnapshot) async {
          try {
            final customerData =
                customerSnapshot.data() as Map<String, dynamic>?;
            log(customerData.toString());
            final favourites = List<String>.from(
              customerData?['favourites'] ?? [],
            );

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
            debugPrint('❌ Error loading wishlist: $e');
            return <ServiceModel>[];
          }
        });
  }

  static Future<void> removeFromWishlist(String serviceId) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot remove from wishlist: User ID is empty');
        return;
      }

      await AppFirestore.customersCollectionRef.doc(currentUid).update({
        'favourites': FieldValue.arrayRemove([serviceId]),
      });
    } catch (e) {
      debugPrint('❌ Error removing from wishlist: $e');
    }
  }

  static Future<CustomerModel> updateCustomerProfile({
    required CustomerModel customerData,
    required CustomerModel previousCustomerData,
  }) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot update customer profile: User ID is empty');
        throw Exception('User ID is empty');
      }

      final updateData = customerData.toEditJson(
        previous: previousCustomerData,
      );
      if (updateData.isNotEmpty) {
        await AppFirestore.customersCollectionRef
            .doc(currentUid)
            .update(updateData);
      }
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

  static Stream<List<ServiceModel>> listenToServicesByCategory(
    String categoryId,
  ) {
    return AppFirestore.servicesCollectionRef
        .where('category', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    ServiceModel.fromJson(doc.data() as Map<String, dynamic>),
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
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot update customer location: User ID is empty');
        return;
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      final existingData = docSnapshot.data() as Map<String, dynamic>?;
      final existingLocation =
          existingData?['location'] as Map<String, dynamic>?;

      await AppFirestore.customersCollectionRef.doc(currentUid).set({
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
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot update customer coordinates: User ID is empty');
        return;
      }

      // Fetch existing customer data to preserve other location fields
      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      final existingData = docSnapshot.data() as Map<String, dynamic>?;
      final existingLocation =
          existingData?['location'] as Map<String, dynamic>?;

      // Merge coordinates with existing location data
      final updatedLocation = {
        'name': existingLocation?['name'] ?? '',
        'name_ar': existingLocation?['name_ar'] ?? '',
        'lat': latitude,
        'lon': longitude,
      };

      await AppFirestore.customersCollectionRef.doc(currentUid).update({
        'location': updatedLocation,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating customer longitude and latitude: $e');
    }
  }

  // Bookings
  static Stream<List<BookingModel>> listenToBookings(String uid) {
    return AppFirestore.bookingsCollectionRef
        .where('customer.uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    BookingModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  static Future<List<AddressModel>> getCustomerAddress() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot get customer address: User ID is empty');
        return [];
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      final data = docSnapshot.data() as Map<String, dynamic>;
      final addresses = data['addresses'] as List<dynamic>;
      return addresses
          .map((address) => AddressModel.fromJson(address))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addCustomerAddress(AddressModel address) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot add customer address: User ID is empty');
        return false;
      }

      await AppFirestore.customersCollectionRef.doc(currentUid).update({
        'addresses': FieldValue.arrayUnion([address.toJson()]),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<AddressModel?>
  getSelectedAddressAndUpdateIsSelectedToFalse() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot get selected address: User ID is empty');
        return null;
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final addresses = (data['addresses'] as List<dynamic>?) ?? [];

        for (var address in addresses) {
          if ((address as Map<String, dynamic>)['isSelected'] == true) {
            // Update all addresses to set isSelected to false
            final updatedAddresses = addresses.map((a) {
              final addr = Map<String, dynamic>.from(a as Map);
              addr['isSelected'] = false;
              return addr;
            }).toList();

            await AppFirestore.customersCollectionRef.doc(currentUid).update({
              'addresses': updatedAddresses,
            });

            return AddressModel.fromJson(address);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting selected address: $e');
      return null;
    }
  }

  static Future<bool> removeAddress(String id) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot remove address: User ID is empty');
        return false;
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final addresses = (data['addresses'] as List<dynamic>?) ?? [];

        final updatedAddresses = addresses
            .where((a) => (a as Map<String, dynamic>)['id'] != id)
            .toList();

        await AppFirestore.customersCollectionRef.doc(currentUid).update({
          'addresses': updatedAddresses,
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error removing address: $e');
    }
    return false;
  }

  static Future<bool> selectLocation(String id) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot select location: User ID is empty');
        return false;
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final addresses = (data['addresses'] as List<dynamic>?) ?? [];

        final updatedAddresses = addresses.map((a) {
          final address = Map<String, dynamic>.from(a as Map);
          address['isSelected'] = address['id'] == id;
          return address;
        }).toList();

        await AppFirestore.customersCollectionRef.doc(currentUid).update({
          'addresses': updatedAddresses,
        });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> cancelBooking(BookingModel booking) async {
    try {
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        'bookingStatusCode': 'X',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling booking: $e');
      return false;
    }
  }

  static Future<bool> checkCustomerPhoneNumberAlredyExist(
    String phoneNumber,
  ) async {
    try {
      String normalizedPhoneNumber = phoneNumber.replaceAll(
        RegExp(r'[^\d+]'),
        '',
      );
      final customerQuery = await AppFirestore.customersCollectionRef
          .where('phone', isEqualTo: normalizedPhoneNumber)
          .limit(1)
          .get();
      if (customerQuery.docs.isEmpty) {
        final customerQueryOriginal = await AppFirestore.customersCollectionRef
            .where('phone', isEqualTo: phoneNumber)
            .limit(1)
            .get();
        return customerQueryOriginal.docs.isNotEmpty;
      }
      return customerQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<void> deleteFCMToken() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot delete FCM token: User ID is empty');
        return;
      }

      await AppFirestore.customersCollectionRef.doc(currentUid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  static Future<void> deleteAccount() async {
    try {
      // Get the current UID dynamically instead of using the static variable
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot delete account: User ID is empty');
        return;
      }

      log('🔒 Deleting account for user: $currentUid');
      await AppFirestore.customersCollectionRef.doc(currentUid).delete();
      LocalStoreHelper.clearGuestUser();
      LocalStoreHelper.putlogoutStatus(true);
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
    }
  }

  Stream<UserModel> getAgentLiveLocationStream(String agentId) {
    return AppFirestore.usersCollectionRef.doc(agentId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return UserModel.fromJson(snapshot.data() as Map<String, dynamic>);
      } else {
        throw Exception('Agent document does not exist');
      }
    });
  }

  static Future<List<BookingModel>> getActiveBookings() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot get active bookings: User ID is empty');
        return [];
      }

      final snapshot = await AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('bookingStatusCode', isEqualTo: 'A')
          .where('isStarted', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map(
            (doc) => BookingModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting active bookings: $e');
      return [];
    }
  }

  static Stream<List<FaqModel>> getFaq() {
    return AppFirestore.faqCollectionRef.snapshots().map((snapshot) {
      List<FaqModel> faqList = snapshot.docs
          .map((doc) => FaqModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      faqList.sort((a, b) => a.stand?.compareTo(b.stand ?? 0) ?? 0);
      return faqList;
    });
  }
}
