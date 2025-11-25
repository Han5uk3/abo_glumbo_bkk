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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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

      // ✅ If still empty, this is a background notification
      // Store with a fallback identifier
      if (userId.isEmpty) {
        debugPrint(
          '⚠️ Background notification received - userId not available, checking targetRole',
        );

        // For background notifications, use targetRole to determine storage
        String targetRole = message.data['targetRole'] ?? 'unknown';

        // Log the message for debugging
        debugPrint(
          '📨 Background notification: role=$targetRole, category=${message.data['category']}',
        );

        // If we truly can't get userId, the notification might be lost
        // Try one more time to extract it from data
        if (userId.isEmpty) {
          debugPrint(
            '❌ Cannot store notification: No userId available in message or Hive',
          );
          return;
        }
      }

      debugPrint('📝 Storing notification for userId: $userId');

      Map<String, dynamic> notificationData = {
        'userId': userId,
        'title': message.notification?.title ?? message.data['title'] ?? '',
        'body': message.notification?.body ?? message.data['body'] ?? '',
        'data': message.data,
        'messageId': message.messageId ?? '',
        'sentTime': message.sentTime != null
            ? Timestamp.fromDate(message.sentTime!)
            : Timestamp.now(),
        'createdAt': Timestamp.now(),
        'isRead': false,
        'category': message.data['category'] ?? 'general',
        'action': message.data['action'] ?? '',
        'platform': message.data['platform'] ?? 'unknown',
        'targetRole': message.data['targetRole'] ?? 'customer',
      };

      await AppFirestore.notificationsCollectionRef.add(notificationData);

      debugPrint('✅ Notification stored successfully');
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

      debugPrint('🔒 Deleting account for user: $currentUid');
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
                (doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  static Future<AddressModel> getCustomerSelectedAddress() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot get customer address: User ID is empty');
        return AddressModel(
          id: '',
          fullName: '',
          buildingNumber: '',
          phoneNumber: '',
        );
      }

      final docSnapshot = await AppFirestore.customersCollectionRef
          .doc(currentUid)
          .get();
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        return AddressModel(
          id: '',
          fullName: '',
          buildingNumber: '',
          phoneNumber: '',
        );
      }

      final addresses = data['addresses'] as List<dynamic>?;
      if (addresses == null || addresses.isEmpty) {
        return AddressModel(
          id: '',
          fullName: '',
          buildingNumber: '',
          phoneNumber: '',
        );
      }

      final selectedAddress =
          addresses.firstWhere(
                (a) => (a as Map<String, dynamic>)['isSelected'] == true,
                orElse: () => null,
              )
              as Map<String, dynamic>?;

      return AddressModel.fromJson(selectedAddress ?? {});
    } catch (e) {
      return AddressModel(
        id: '',
        fullName: '',
        buildingNumber: '',
        phoneNumber: '',
      );
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
    // Step 2: Get workers stream
    final workersStream = AppFirestore.usersCollectionRef
        .where('jobRoles', arrayContains: categoryDocId)
        .where('isAdmin', isEqualTo: false)
        .where('isOnline', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });

    // Step 3: Switch to the combined streams for each worker
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
  static Stream<int> getUnreadNotificationCount() {
    String currentUid = LocalStoreHelper.getUID() ?? '';
    if (currentUid.isEmpty) {
      return Stream.value(0);
    }

    return AppFirestore.notificationsCollectionRef
        .where('userId', isEqualTo: currentUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark single notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot mark notification as read: User ID is empty');
        return;
      }

      await AppFirestore.notificationsCollectionRef.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read (batch operation)
  static Future<void> markAllNotificationsAsRead() async {
    try {
      String currentUid = LocalStoreHelper.getUID() ?? '';
      if (currentUid.isEmpty) {
        debugPrint('❌ Cannot mark all as read: User ID is empty');
        return;
      }

      final snapshot = await AppFirestore.notificationsCollectionRef
          .where('userId', isEqualTo: currentUid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No unread notifications to mark');
        return;
      }

      // Batch write operation
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ All ${snapshot.docs.length} notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
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

  static void requestWarrantyRepair(BookingModel booking) async {
    try {
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        'warranty.availability': true,
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

    return AppFirestore.usersCollectionRef
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

    await AppFirestore.usersCollectionRef
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  static Future<void> deleteAllFirestoreNotifications() async {
    String userId = LocalStoreHelper.getUID() ?? '';
    if (userId.isEmpty) return;

    final collection = AppFirestore.usersCollectionRef
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

    return AppFirestore.usersCollectionRef
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
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
