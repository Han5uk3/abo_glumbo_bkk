import 'dart:math';

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/banner.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/customer_support.dart';
import 'package:abo_glumbo_bbk/models/faq.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/models/notification.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/models/counter_offer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:abo_glumbo_bbk/models/job_request.dart';
import 'package:rxdart/rxdart.dart';

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
      // ✅ Try to get userId from message data first (cloud function sends it)
      String userId = message.data['customerId']?.toString() ?? '';

      // ✅ Only try Hive if message doesn't have userId AND Hive is open
      if (userId.isEmpty && Hive.isBoxOpen('myBox')) {
        try {
          userId = LocalStoreHelper.getUID() ?? '';
        } catch (e) {
          debugPrint('⚠️ Could not get UID from Hive: $e');
        }
      }

      // ✅ If still empty, cannot store notification
      if (userId.isEmpty) {
        debugPrint(
          '❌ Cannot store notification: No userId available in message or Hive',
        );
        return;
      }

      debugPrint('📝 Storing notification for customerId: $userId');

      String title =
          message.notification?.title ??
          message.data['title'] ??
          'New Notification';
      String body =
          message.notification?.body ??
          message.data['body'] ??
          'You have a new notification';

      // Store notification data matching Cloud Functions format
      Map<String, dynamic> notificationData = {
        'titleEn': message.data['titleEn'] ?? title,
        'titleAr': message.data['titleAr'] ?? title,
        'bodyEn': message.data['bodyEn'] ?? body,
        'bodyAr': message.data['bodyAr'] ?? body,
        'data': message.data.isNotEmpty ? message.data : {},
        'read': false,
        'createdAt': Timestamp.now(),
      };

      // Store in customer-specific subcollection: customers/{customerId}/notifications
      await AppFirestore.customersCollectionRef
          .doc(userId)
          .collection('notifications')
          .add(notificationData);

      debugPrint(
        '✅ Notification stored in customers/$userId/notifications subcollection',
      );
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
      debugPrint('🔑 Token: $token');

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
    if (uid.isEmpty) {
      throw Exception('fetchCustomerData called with empty UID');
    }
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
    if (uid.isEmpty) {
      debugPrint('⚠️ listenToCustomerData called with empty UID');
      return const Stream.empty();
    }
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
        if (updateData.containsKey('name')) {
          await LocalStoreHelper.putUserName(customerData.name ?? '');
        }
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
                (doc) => CategoryModel.fromQuerySnapshot(doc),
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
                (doc) => ServiceModel.fromQueryDocumentSnapshot(doc),
              )
              .toList();
        });
  }

  static Stream<List<ServiceModel>> listenToServices() {
    return AppFirestore.servicesCollectionRef
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => ServiceModel.fromQueryDocumentSnapshot(doc),
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

  static Stream<List<BannerModel>> listenToBanners() {
    return AppFirestore.bannersCollectionRef
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    BannerModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
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

  static Future<bool> cancelBooking(BookingModel booking, String reason) async {
    try {
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        'bookingStatusCode': 'XC',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling booking: $e');
      return false;
    }
  }

  static Future<bool> checkCustomerPhoneNumberAlredyExist(
    String phoneNumber, {
    String? excludeUid,
  }) async {
    try {
      String normalizedPhoneNumber = phoneNumber.replaceAll(
        RegExp(r'[^\d+]'),
        '',
      );

      // Query customers with the phone number (normalized)
      var customerQuery = AppFirestore.customersCollectionRef.where(
        'phone',
        isEqualTo: normalizedPhoneNumber,
      );

      // If excludeUid is provided, exclude the current user
      if (excludeUid != null) {
        customerQuery = customerQuery.where('uid', isNotEqualTo: excludeUid);
      }

      final result = await customerQuery.limit(1).get();
      if (result.docs.isNotEmpty) {
        return true;
      }

      // Try with original phoneNumber format
      var customerQueryOriginal = AppFirestore.customersCollectionRef.where(
        'phone',
        isEqualTo: phoneNumber,
      );

      if (excludeUid != null) {
        customerQueryOriginal = customerQueryOriginal.where(
          'uid',
          isNotEqualTo: excludeUid,
        );
      }

      final resultOriginal = await customerQueryOriginal.limit(1).get();
      return resultOriginal.docs.isNotEmpty;
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

      debugPrint('🔒 Deleting account for user: $currentUid');
      await AppFirestore.customersCollectionRef.doc(currentUid).delete();

      // Clear local biometric settings and UID credentials immediately
      await LocalStoreHelper.clearBiometricAuthEnabled(currentUid);
      await LocalStoreHelper.clearUID();
      await LocalStoreHelper.clearLastValidUID();

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
        return UserModel.fromDocumentSnapshot(snapshot);
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

      // 1. Normal Active Bookings
      final activeBookingsFuture = AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('bookingStatusCode', isEqualTo: 'A')
          .where('isStarted', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      // 2. Active Warranty Bookings (Accepted & Started)
      final warrantyBookingsFuture = AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('warranty.warrantyStatusCode', isEqualTo: 'S')
          .where('isStarted', isEqualTo: true)
          .get();

      final results = await Future.wait([
        activeBookingsFuture,
        warrantyBookingsFuture,
      ]);

      final Map<String, BookingModel> bookingMap = {};

      // Process normal active bookings
      for (var doc in results[0].docs) {
        final booking = BookingModel.fromJson(
          doc.data() as Map<String, dynamic>,
        );
        bookingMap[booking.id] = booking;
      }

      // Process active warranty bookings
      for (var doc in results[1].docs) {
        final booking = BookingModel.fromJson(
          doc.data() as Map<String, dynamic>,
        );
        bookingMap[booking.id] = booking;
      }

      final combined = bookingMap.values.toList();

      // Sort by createdAt descending
      combined.sort((a, b) {
        final aTime = a.createdAt?.toDate() ?? DateTime(0);
        final bTime = b.createdAt?.toDate() ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      return combined;
    } catch (e) {
      debugPrint('❌ Error getting active bookings: $e');
      return [];
    }
  }

  static Stream<List<BookingModel>> listenToActiveBookings() {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot listen to active bookings: User ID is empty');
        return Stream.value([]);
      }

      // 1. Normal Active Bookings
      final activeBookingsStream = AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('bookingStatusCode', isEqualTo: 'A')
          .where('isStarted', isEqualTo: true)
          .snapshots();

      // 2. Active Warranty Bookings (Accepted & Started)
      final warrantyBookingsStream = AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('warranty.warrantyStatusCode', isEqualTo: 'S')
          .where('isStarted', isEqualTo: true)
          .snapshots();

      return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<BookingModel>>(
        activeBookingsStream,
        warrantyBookingsStream,
        (activeSnapshot, warrantySnapshot) {
          final Map<String, BookingModel> bookingMap = {};

          // Process normal active bookings
          for (var doc in activeSnapshot.docs) {
            final booking = BookingModel.fromJson(
              doc.data() as Map<String, dynamic>,
            );
            bookingMap[booking.id] = booking;
          }

          // Process active warranty bookings
          for (var doc in warrantySnapshot.docs) {
            final booking = BookingModel.fromJson(
              doc.data() as Map<String, dynamic>,
            );
            bookingMap[booking.id] = booking;
          }

          final combined = bookingMap.values.toList();

          // Sort by createdAt descending
          combined.sort((a, b) {
            final aTime = a.createdAt?.toDate() ?? DateTime(0);
            final bTime = b.createdAt?.toDate() ?? DateTime(0);
            return bTime.compareTo(aTime);
          });

          return combined;
        },
      );
    } catch (e) {
      debugPrint('❌ Error listening to active bookings: $e');
      return Stream.value([]);
    }
  }

  static Stream<List<BookingModel>> listenToAcceptedBookings() {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot listen to accepted bookings: User ID is empty');
        return Stream.value([]);
      }

      // 1. Normal Accepted Bookings
      final activeBookingsStream = AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('bookingStatusCode', isEqualTo: 'A')
          .snapshots();

      // 2. Warranty Active/Started Bookings
      final warrantyBookingsStream = AppFirestore.bookingsCollectionRef
          .where('customer.uid', isEqualTo: currentUid)
          .where('warranty.warrantyStatusCode', isEqualTo: 'S')
          .snapshots();

      return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<BookingModel>>(
        activeBookingsStream,
        warrantyBookingsStream,
        (activeSnapshot, warrantySnapshot) {
          final Map<String, BookingModel> bookingMap = {};

          // Process normal active bookings
          for (var doc in activeSnapshot.docs) {
            final booking = BookingModel.fromJson(
              doc.data() as Map<String, dynamic>,
            );
            bookingMap[booking.id] = booking;
          }

          // Process active warranty bookings
          for (var doc in warrantySnapshot.docs) {
            final booking = BookingModel.fromJson(
              doc.data() as Map<String, dynamic>,
            );
            bookingMap[booking.id] = booking;
          }

          final combined = bookingMap.values.toList();

          // Sort by createdAt descending
          combined.sort((a, b) {
            final aTime = a.createdAt?.toDate() ?? DateTime(0);
            final bTime = b.createdAt?.toDate() ?? DateTime(0);
            return bTime.compareTo(aTime);
          });

          return combined;
        },
      );
    } catch (e) {
      debugPrint('❌ Error listening to accepted bookings: $e');
      return Stream.value([]);
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

  static Stream<List<UserModel>> getWorkersByRoles(
    String categoryDocId,
  ) async* {
    // Step 1: Get the category name from its document
    final categorySnapshot = await AppFirestore.categoriesCollectionRef
        .doc(categoryDocId)
        .get();

    if (!categorySnapshot.exists) {
      // Return empty stream if the document doesn’t exist
      yield [];
      return;
    }

    final categoryData = categorySnapshot.data() as Map<String, dynamic>;
    final categoryName = categoryData['name'];

    // Step 2: Query users whose jobRoles includes that category name
    yield* AppFirestore.usersCollectionRef
        .where('jobRoles', arrayContains: categoryName)
        .where('isAdmin', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => UserModel.fromDocumentSnapshot(doc),
              )
              .toList();
        });
  }

  static Future<AddressModel?> getCustomerSelectedAddress() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot get customer address: User ID is empty');
        return null;
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }

      final addresses = data['addresses'] as List<dynamic>?;
      if (addresses == null || addresses.isEmpty) {
        return null;
      }

      final selectedAddressMap =
          addresses.firstWhere(
                (a) => (a as Map<String, dynamic>)['isSelected'] == true,
                orElse: () => null,
              )
              as Map<String, dynamic>?;

      if (selectedAddressMap == null) {
        return null;
      }

      return AddressModel.fromJson(selectedAddressMap);
    } catch (e) {
      debugPrint('❌ Error getting selected address: $e');
      return null;
    }
  }

  static Stream<List<CustomerSupportModel>> getCustomerSupportdata() {
    return AppFirestore.customerSupportCollectionRef
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          List<CustomerSupportModel> customerSupportList = snapshot.docs
              .map(
                (doc) => CustomerSupportModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
          return customerSupportList;
        });
  }

  static Stream<Map<String, dynamic>> getWorkerRating(String workerId) {
    return AppFirestore.bookingsCollectionRef
        .where('agent.uid', isEqualTo: workerId)
        .where('bookingStatusCode', isEqualTo: 'C')
        .where('review.rating', isNull: false)
        .snapshots()
        .map((snapshot) {
          // ✅ FIXED: Extract the nested 'review' field from each booking document
          List<ReviewModel> reviewList = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // Access the nested 'review' map
                final reviewData = data['review'] as Map<String, dynamic>?;

                if (reviewData != null) {
                  return ReviewModel.fromMap(reviewData);
                }
                return null;
              })
              .where((review) => review != null)
              .cast<ReviewModel>()
              .toList();

          double rating = 0;

          // Filter out null ratings before processing
          final validRatings = reviewList
              .where((review) => review.rating != null)
              .map((review) => review.rating!)
              .toList();

          if (validRatings.isNotEmpty) {
            final totalRating = validRatings.reduce((a, b) => a + b);

            rating = totalRating / (validRatings.length);
          }

          return {
            'count': validRatings.length,
            'rating': double.tryParse(rating.toStringAsFixed(2)),
          };
        });
  }

  static Stream<int> getCompletedJobsByWorkerId(String workerId) {
    return AppFirestore.bookingsCollectionRef
        .where('agent.uid', isEqualTo: workerId)
        .where('bookingStatusCode', isEqualTo: 'C')
        .where('paymentCompleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Alternative approach: Using RxDart's combineLatest for real-time updates
  static Stream<List<WorkerWithStats>> getWorkersByRolesWithStatsRealtime(
    String categoryDocId,
  ) async* {
    // 3. Workers stream
    final workersStream = AppFirestore.usersCollectionRef
        .where('jobRoles', arrayContains: categoryDocId)
        // .where('isAdmin', isEqualTo: false) // Removed to include admins
        // .where('isOnline', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => UserModel.fromDocumentSnapshot(doc),
              )
              .where((user) {
                // Filter logic for admin roles: Exclude customer service admins
                if (user.isAdmin == true) {
                  final r = user.role.toLowerCase();
                  if (r.contains('customer service') ||
                      r.contains('support') ||
                      r == 'customer_service') {
                    return false;
                  }
                }
                return user.isOnline == true && user.isVerified == true;
              })
              .toList();
        });

    // 4. Combine with stats (removed busy agent checking from here as it's handled in UI)
    yield* workersStream.switchMap((workers) {
      if (workers.isEmpty) {
        return Stream.value(<WorkerWithStats>[]);
      }

      // Create a list of combined streams for each worker
      final workerStreams = workers.map((worker) {
        return Rx.combineLatest3<
          UserModel,
          Map<String, dynamic>,
          int,
          WorkerWithStats
        >(
          Stream.value(worker), // Worker data
          getWorkerRating(worker.uid ?? ""), // Rating stream
          getCompletedJobsByWorkerId(worker.uid ?? ''), // Completed jobs stream
          (worker, rating, completedJobs) => WorkerWithStats(
            worker: worker,
            rating: rating['rating'] ?? 0,
            completedJobs: completedJobs,
            reviewCount: rating['count'] ?? 0,
          ),
        );
      }).toList();

      // Combine all worker streams into one
      return Rx.combineLatestList(workerStreams);
    });
  }

  static Future<Map<String, dynamic>> fetchCategory(
    String categoryDocId,
  ) async {
    final categorySnapshot = await AppFirestore.categoriesCollectionRef
        .doc(categoryDocId)
        .get();
    if (!categorySnapshot.exists) {
      return {};
    }
    final categoryData = categorySnapshot.data() as Map<String, dynamic>;

    return categoryData;
  }

  /// Fetch multiple categories by their IDs in batch (handles Firestore's whereIn limit of 10)
  static Future<List<CategoryModel>> getCategoriesByIds(
    List<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return [];

    try {
      // Split into chunks of 10 due to Firestore whereIn limit
      List<List<String>> chunks = [];
      for (int i = 0; i < categoryIds.length; i += 10) {
        chunks.add(categoryIds.sublist(i, min(i + 10, categoryIds.length)));
      }

      // Fetch all chunks in parallel
      List<Future<QuerySnapshot>> futures = chunks
          .map(
            (chunk) => FirebaseFirestore.instance
                .collection('categories')
                .where(FieldPath.documentId, whereIn: chunk)
                .get(),
          )
          .toList();

      List<QuerySnapshot> snapshots = await Future.wait(futures);

      List<CategoryModel> categories = [];
      for (var snapshot in snapshots) {
        categories.addAll(
          snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Add document ID to the data
            return CategoryModel.fromJson(data);
          }).toList(),
        );
      }

      return categories;
    } catch (e) {
      debugPrint('Error fetching categories by IDs: $e');
      return [];
    }
  }

  /// Fetch a single category by ID (for backward compatibility)
  static Future<CategoryModel?> getCategoryByIdOnce(String categoryId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return CategoryModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching category $categoryId: $e');
      return null;
    }
  }

  /// Fetch category ID by job role name (one-time read)
  static Future<String?> getCategoryIdByJobRoleOnce(String jobRole) async {
    try {
      QuerySnapshot querySnapshot = await AppFirestore.categoriesCollectionRef
          .where('id', isEqualTo: jobRole)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        String categoryId = querySnapshot.docs.first.id;

        return categoryId;
      }

      // If not found by English name, try Arabic name
      QuerySnapshot querySnapshotAr = await AppFirestore.categoriesCollectionRef
          .where('name_ar', isEqualTo: jobRole)
          .limit(1)
          .get();

      if (querySnapshotAr.docs.isNotEmpty) {
        String categoryId = querySnapshotAr.docs.first.id;
        return categoryId;
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching category ID for job role $jobRole: $e');
      return null;
    }
  }

  // Get count of unread notifications
  // Get unread notification count from subcollection
  static Stream<int> getUnreadNotificationCount() {
    String currentUid = LocalStoreHelper.getUID() ?? '';
    if (currentUid.isEmpty) {
      return Stream.value(0);
    }

    return AppFirestore.customersCollectionRef
        .doc(currentUid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark single notification as read
  // Mark single notification as read from subcollection
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot mark notification as read: User ID is empty');
        return;
      }

      await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // Delete all notifications from subcollection
  static Future<bool> deleteAllNotifications() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot delete notifications: User ID is empty');
        return false;
      }

      final snapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .collection('notifications')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No notifications to delete');
        return true;
      }

      // Batch delete operation
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ All ${snapshot.docs.length} notifications deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting all notifications: $e');
      return false;
    }
  }

  // Mark all notifications as read (batch operation)
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot mark all as read: User ID is empty');
        return false;
      }

      // Query from subcollection: customers/{userId}/notifications
      final snapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No unread notifications to mark');
        return true;
      }

      // Batch write operation
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ All ${snapshot.docs.length} notifications marked as read');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  // Get user notifications with role-based filtering
  static Future<List<Map<String, dynamic>>> getUserNotifications({
    int limit = 20,
    bool onlyUnread = false,
  }) async {
    try {
      String userId = LocalStoreHelper.getUID() ?? '';
      if (userId.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No user logged in, cannot retrieve notifications');
        }
        return [];
      }

      // Query from subcollection: customers/{userId}/notifications
      Query query = AppFirestore.customersCollectionRef
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true);

      if (onlyUnread) {
        query = query.where('read', isEqualTo: false);
      }

      QuerySnapshot querySnapshot = await query.limit(limit).get();

      List<Map<String, dynamic>> notifications = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Convert to format expected by notifications page
        // Cloud Functions store: titleEn, titleAr, bodyEn, bodyAr
        // Notifications page expects: title, body (single language)
        return {
          'id': doc.id,
          'title': data['titleEn'] ?? data['titleAr'] ?? '',
          'body': data['bodyEn'] ?? data['bodyAr'] ?? '',
          'titleEn': data['titleEn'] ?? '',
          'titleAr': data['titleAr'] ?? '',
          'bodyEn': data['bodyEn'] ?? '',
          'bodyAr': data['bodyAr'] ?? '',
          'data': data['data'] ?? {},
          'isRead': data['read'] ?? false,
          'createdAt': data['createdAt'],
          'category':
              (data['data'] as Map<String, dynamic>?)?['category'] ?? 'general',
        };
      }).toList();

      if (kDebugMode) {
        print(
          '📱 Retrieved ${notifications.length} notifications for customer from subcollection',
        );
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error retrieving notifications: $e');
      }
      return [];
    }
  }

  static Stream<List<BookingModel?>> getBookingsWithWarranty(
    String customerId,
  ) {
    return AppFirestore.bookingsCollectionRef
        .where('customer.uid', isEqualTo: customerId)
        .where('bookingStatusCode', isEqualTo: "C")
        .where('paymentCompleted', isEqualTo: true)
        .where('warranty', isNull: false)
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

  static Future<void> requestWarrantyRepair(BookingModel booking) async {
    try {
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        'warranty.availability': true,
        'warranty.warrantyStatusCode': 'R',
        'warranty.requestedOn': FieldValue.serverTimestamp(),
        'warranty.updatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error requesting warranty repair: $e');
    }
  }

  static Future<String> getroleNameArbyid(String id) async {
    DocumentSnapshot value = await AppFirestore.categoriesCollectionRef
        .doc(id)
        .get();
    return value.get('name_ar') as String;
  }

  static Future<String> getroleNameEnbyid(String id) async {
    DocumentSnapshot value = await AppFirestore.categoriesCollectionRef
        .doc(id)
        .get();
    return value.get('name') as String;
  }

  static Stream<List<NotificationModel>> getNotificationsStream() {
    String userId = LocalStoreHelper.getUID() ?? '';
    if (userId.isEmpty) return Stream.value([]);

    return AppFirestore.customersCollectionRef
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
        });
  }

  static Future<void> markFirestoreNotificationAsRead(
    String notificationId,
  ) async {
    String userId = LocalStoreHelper.getUID() ?? '';
    if (userId.isEmpty) return;

    await AppFirestore.customersCollectionRef
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  static Future<void> deleteFirestoreNotification(String notificationId) async {
    String userId = LocalStoreHelper.getUID() ?? '';
    if (userId.isEmpty) return;

    await AppFirestore.customersCollectionRef
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  static Future<void> deleteAllFirestoreNotifications() async {
    String userId = LocalStoreHelper.getUID() ?? '';
    if (userId.isEmpty) return;

    final collection = AppFirestore.customersCollectionRef
        .doc(userId)
        .collection('notifications');

    final snapshot = await collection.get();
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  static Stream<int> getUnreadNotificationsCountStream() {
    String userId = LocalStoreHelper.getUID() ?? '';
    if (userId.isEmpty) return Stream.value(0);

    return AppFirestore.customersCollectionRef
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Future<bool> createCounterOffer({
    required String bookingId,
    required String proposedBy,
    required String proposedByUid,
    required String proposedByName,
    required Timestamp proposedTime,
    required String? agentUid,
  }) async {
    try {
      debugPrint('📝 Creating counter offer for booking: $bookingId');
      final docRef = AppFirestore.counterOffersCollectionRef.doc();
      final counterOffer = CounterOfferModel(
        id: docRef.id,
        bookingId: bookingId,
        proposedBy: proposedBy,
        proposedByUid: proposedByUid,
        proposedByName: proposedByName,
        proposedTime: proposedTime,
        status: 'pending',
        createdAt: Timestamp.now(),
      );

      // Fetch any existing counter_offered job offers for this booking
      final offers = await AppFirestore.jobOffersCollectionRef
          .where('bookingId', isEqualTo: bookingId)
          .where('status', isEqualTo: 'counter_offered')
          .get();
      debugPrint('📝 Found ${offers.docs.length} counter_offered job offers');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final bookingRef = AppFirestore.bookingsCollectionRef.doc(bookingId);
        final bookingSnapshot = await transaction.get(bookingRef);

        Map<String, dynamic> updateData = {
          'activeCounterOffer': counterOffer.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Set startedAt if not already set
        if (bookingSnapshot.exists) {
          final data = bookingSnapshot.data() as Map<String, dynamic>;
          if (data['counterProposalStartedAt'] == null) {
            updateData['counterProposalStartedAt'] =
                FieldValue.serverTimestamp();
          }
        }

        transaction.set(docRef, counterOffer.toMap());
        transaction.update(bookingRef, updateData);

        // Update any associated rebook job offers
        for (var doc in offers.docs) {
          transaction.update(doc.reference, {
            'status': 'customer_counter_offered',
            'proposedTime': proposedTime,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('✅ Counter offer created successfully: ${docRef.id}');

      if (agentUid != null && agentUid.isNotEmpty) {
        await recordTechnicianNotification(
          technicianId: agentUid,
          titleEn: 'Counter Offer Update',
          titleAr: 'تحديث عرض الموعد البديل',
          bodyEn: 'Customer has proposed a new time for the booking.',
          bodyAr: 'لقد اقترح العميل وقتاً جديداً للحجز.',
          type: 'counter_offer',
          data: {'bookingId': bookingId},
        );
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating counter offer: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }


  static Future<bool> respondToCounterOffer({
    required BookingModel booking,
    required String response, // 'accepted' or 'rejected'
  }) async {
    try {
      final bookingId = booking.id;
      final activeCounterOffer = booking.activeCounterOffer;
      if (activeCounterOffer == null) return false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final bookingRef = AppFirestore.bookingsCollectionRef.doc(bookingId);
        final offerRef = AppFirestore.counterOffersCollectionRef.doc(
          activeCounterOffer.id!,
        );

        if (response == 'accepted') {
          transaction.update(bookingRef, {
            'bookingDateTime': activeCounterOffer.proposedTime,
            'activeCounterOffer.status': response,
            'counterProposalAcceptedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(bookingRef, {
            'activeCounterOffer.status': response,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(offerRef, {
          'status': response,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (booking.agent?.uid != null) {
        await recordTechnicianNotification(
          technicianId: booking.agent!.uid!,
          titleEn: 'Counter Offer Response',
          titleAr: 'الرد على عرض الموعد البديل',
          bodyEn: 'Customer has $response your proposed time.',
          bodyAr: response == 'accepted'
              ? 'لقد قبل العميل الوقت المقترح.'
              : 'لقد رفض العميل الوقت المقترح.',
          type: 'counter_offer_response',
          data: {'bookingId': bookingId, 'status': response},
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error responding to counter offer: $e');
      return false;
    }
  }

  static Future<void> recordTechnicianNotification({
    required String technicianId,
    required String titleEn,
    required String titleAr,
    required String bodyEn,
    required String bodyAr,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await AppFirestore.usersCollectionRef
          .doc(technicianId)
          .collection('notifications')
          .add({
            'titleEn': titleEn,
            'titleAr': titleAr,
            'bodyEn': bodyEn,
            'bodyAr': bodyAr,
            'type': type,
            'data': data,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
    } catch (e) {
      debugPrint('Error recording technician notification: $e');
    }
  }

  static Future<void> recordCustomerNotification({
    required String customerId,
    required String titleEn,
    required String titleAr,
    required String bodyEn,
    required String bodyAr,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await AppFirestore.customersCollectionRef
          .doc(customerId)
          .collection('notifications')
          .add({
        'titleEn': titleEn,
        'titleAr': titleAr,
        'bodyEn': bodyEn,
        'bodyAr': bodyAr,
        'type': type,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Error recording customer notification: $e');
    }
  }

  static Future<String> broadcastJobRequest({
    required JobRequestModel request,
    required List<String> workerIds,
    bool isRebook = false,
  }) async {
    try {
      // 1. Save Job Request
      await AppFirestore.jobRequestsCollectionRef
          .doc(request.id)
          .set(request.toJson());

      // 2. Create Job Offers for each worker
      final batch = FirebaseFirestore.instance.batch();
      for (var workerId in workerIds) {
        final offerId = AppFirestore.jobOffersCollectionRef.doc().id;
        batch.set(AppFirestore.jobOffersCollectionRef.doc(offerId), {
          'id': offerId,
          'requestId': request.id,
          'technicianId': workerId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': request.expiresAt,
          'customerName': request.customer.name,
          'serviceLocation': request.address.toJson(),
          'serviceName': request.service.name,
          'serviceNameAr': request.service.name_ar,
          'serviceNameUr': request.service.name_ur,
          'notes': request.notes,
          'issueImage': request.issueImage,
          'issueVideo': request.issueVideo,
          'bookingDateTime': request.bookingDateTime,
          'isRebook': isRebook,
          'customerId': request.customer.uid,
        });
      }
      await batch.commit();
      
      return request.id;
    } catch (e) {
      debugPrint('Error broadcasting job request: $e');
      rethrow;
    }
  }

  static Stream<List<String>> listenToInterestedWorkers(String requestId) {
    return AppFirestore.jobOffersCollectionRef
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'accepted_by_technician';
              })
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['technicianId'] as String;
              })
              .toList();
        });
  }

  static Future<List<UserModel>> getWorkersByIds(List<String> workerIds) async {
    if (workerIds.isEmpty) return [];

    // Firestore whereIn is limited to 10 items
    final List<UserModel> workers = [];
    for (var i = 0; i < workerIds.length; i += 10) {
      final chunk = workerIds.sublist(
        i,
        i + 10 > workerIds.length ? workerIds.length : i + 10,
      );
      final snapshot = await AppFirestore.usersCollectionRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      workers.addAll(
        snapshot.docs.map((doc) => UserModel.fromDocumentSnapshot(doc)),
      );
    }
    return workers;
  }

  static Future<void> finalizeBooking({
    required String requestId,
    required UserModel selectedTechnician,
  }) async {
    final requestDoc = await AppFirestore.jobRequestsCollectionRef
        .doc(requestId)
        .get();
    if (!requestDoc.exists) throw Exception('Job request not found');

    final data = requestDoc.data() as Map<String, dynamic>;
    final request = JobRequestModel.fromJson(data);

    // Create a standard booking from the job request
    final bookingId = AppFirestore.bookingsCollectionRef.doc().id;
    final booking = {
      'id': bookingId,
      'customerId': request.customer.uid,
      'customer': request.customer.toJson(),
      'agent': {
        'uid': selectedTechnician.uid,
        'name': selectedTechnician.name,
        'phone': selectedTechnician.phone,
        'profileUrl': selectedTechnician.profileUrl,
      },
      'service': request.service.toJson(),
      'address': request.address.toJson(),
      'bookingDateTime': request.bookingDateTime ?? request.createdAt,
      'bookingStatusCode': 'A', // Accepted
      'paymentModeCode': 'O', // Default to Cash (O)
      'paymentCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isOnHour': request.isOnHour,
      'notes': request.notes,
      'issueImage': request.issueImage,
      'issueVideo': request.issueVideo,
      'requestId': requestId,
      'assignedAt': FieldValue.serverTimestamp(),
      'technicianSelectedAt': FieldValue.serverTimestamp(),
    };

    final batch = FirebaseFirestore.instance.batch();

    // 1. Create booking
    batch.set(AppFirestore.bookingsCollectionRef.doc(bookingId), booking);

    // 2. Update request status
    batch.update(AppFirestore.jobRequestsCollectionRef.doc(requestId), {
      'status': 'finalized',
      'bookingId': bookingId,
    });

    // 3. Mark all offers for this request as closed/finalized
    final offers = await AppFirestore.jobOffersCollectionRef
        .where('requestId', isEqualTo: requestId)
        .get();
    for (var doc in offers.docs) {
      batch.update(doc.reference, {'status': 'closed'});
    }

    await batch.commit();
  }

  static Future<void> cancelJobRequest(String requestId) async {
    try {
      await AppFirestore.jobRequestsCollectionRef.doc(requestId).update({
        'status': 'cancelled',
      });
      // Optionally expire all offers
      final offers = await AppFirestore.jobOffersCollectionRef
          .where('requestId', isEqualTo: requestId)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in offers.docs) {
        batch.update(doc.reference, {'status': 'cancelled'});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error cancelling job request: $e');
    }
  }

  static Future<void> deleteJobRequest(String requestId) async {
    try {
      debugPrint('🗑️ Deleting Job Request and Offers for: $requestId');
      
      // 1. Delete associated Job Offers
      final offers = await AppFirestore.jobOffersCollectionRef
          .where('requestId', isEqualTo: requestId)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in offers.docs) {
        batch.delete(doc.reference);
      }
      
      // 2. Delete the Job Request itself
      batch.delete(AppFirestore.jobRequestsCollectionRef.doc(requestId));
      
      await batch.commit();

      debugPrint('✅ Successfully deleted Job Request and Offers');
    } catch (e) {
      debugPrint('❌ Error deleting job request: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> listenToJobOffersForBooking(
    String bookingId,
  ) {
    return AppFirestore.jobOffersCollectionRef
        .where('bookingId', isEqualTo: bookingId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList(),
        );
  }

  static Stream<List<Map<String, dynamic>>> listenToJobOffersForRequest(
    String requestId,
  ) {
    return AppFirestore.jobOffersCollectionRef
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList(),
        );
  }

  static Future<bool> respondToJobOfferForRequest({
    required String requestId,
    required String offerId,
    required String status,
  }) async {
    try {
      await AppFirestore.jobOffersCollectionRef.doc(offerId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final offerDoc = await AppFirestore.jobOffersCollectionRef.doc(offerId).get();
      if (offerDoc.exists) {
        final offerData = offerDoc.data() as Map<String, dynamic>;
        final technicianId = offerData['technicianId'];
        final customerName = offerData['customerName'] ?? 'Customer';

        if (technicianId != null) {
          if (status == 'accepted_by_customer') {
            await recordTechnicianNotification(
              technicianId: technicianId,
              titleEn: 'Counter Offer Accepted',
              titleAr: 'تم قبول عرض الموعد البديل',
              bodyEn: '$customerName has accepted your proposed time.',
              bodyAr: 'لقد قبل $customerName الوقت المقترح.',
              type: 'counter_offer_accepted',
              data: {'requestId': requestId},
            );
          } else if (status == 'declined') {
            await recordTechnicianNotification(
              technicianId: technicianId,
              titleEn: 'Counter Offer Declined',
              titleAr: 'تم رفض عرض الموعد البديل',
              bodyEn: '$customerName has declined your proposed time.',
              bodyAr: 'لقد رفض $customerName الوقت المقترح.',
              type: 'counter_offer_declined',
              data: {'requestId': requestId},
            );
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error responding to job offer for request: $e');
      return false;
    }
  }

  static Future<void> respondToJobOffer({
    required String bookingId,
    required String offerId,
    required bool accept,
    required Timestamp? proposedTime,
    required String technicianId,
    bool isRebook = false,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    if (accept && proposedTime != null) {
      // Fetch technician data
      final techSnapshot = await AppFirestore.usersCollectionRef
          .doc(technicianId)
          .get();
      if (techSnapshot.exists) {
        final techData = techSnapshot.data() as Map<String, dynamic>;
        batch.update(AppFirestore.bookingsCollectionRef.doc(bookingId), {
          'bookingDateTime': proposedTime,
          'bookingStatusCode': 'A',
          'agent': {
            'uid': techData['uid'],
            'name': techData['name'],
            'phone': techData['phone'],
            'profileUrl': techData['profileUrl'],
          },
          'autoAssignmentStatus': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
          'assignedAt': FieldValue.serverTimestamp(),
          'technicianSelectedAt': FieldValue.serverTimestamp(),
        });

        batch.update(AppFirestore.jobOffersCollectionRef.doc(offerId), {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Mark all other offers as closed
        final allOffers = await AppFirestore.jobOffersCollectionRef
            .where('bookingId', isEqualTo: bookingId)
            .get();
        for (var doc in allOffers.docs) {
          if (doc.id != offerId) {
            batch.update(doc.reference, {
              'status': 'closed',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } else {
      // Decline offer
      batch.update(AppFirestore.jobOffersCollectionRef.doc(offerId), {
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      if (isRebook) {
        // If rebook and rejected/declined, fallback to general search
        await fallbackToGeneralSearch(bookingId, technicianId);
      }
    }

    await batch.commit();
  }

  static Future<void> fallbackToGeneralSearch(String bookingId, [String? technicianId]) async {
    final batch = FirebaseFirestore.instance.batch();

    final updateData = <String, dynamic>{
      'rebookTechnicianId': null,
      'agent': null,
      'bookingStatusCode': 'P',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (technicianId != null) {
      updateData['cancelledWorkerUids'] = FieldValue.arrayUnion([technicianId]);
    }

    batch.update(AppFirestore.bookingsCollectionRef.doc(bookingId), updateData);

    // Mark any pending rebook offers as expired
    final offers = await AppFirestore.jobOffersCollectionRef
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (var doc in offers.docs) {
      batch.update(doc.reference, {
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}

class WorkerWithStats {
  final UserModel worker;
  final double rating;
  final int completedJobs;
  final int reviewCount;

  WorkerWithStats({
    required this.worker,
    required this.rating,
    required this.completedJobs,
    required this.reviewCount,
  });
}
