import 'dart:developer';
import 'dart:io';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/tipping.dart';
import 'package:abo_glumbo_bbk/models/total_tip.dart';
import 'package:abo_glumbo_bbk/models/transaction.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/services/unified_payout_services.dart';

class BookingUtils {
  static String getPaymentModeCode(String paymentMode) {
    switch (paymentMode) {
      case "Cards":
        return "C";
      case "Apple Pay":
        return "A";
      case "Cash On Hands":
        return "O";
      default:
        return "U"; // Unknown
    }
  }

  static Future<bool> saveBooking({
    required ServiceModel service,
    required DateTime selectedDate,
    required String paymentMode,
    required CustomerModel customerData,
    required String notes,
    File? selectedImage,
    File? selectedVideo,
    required Map timeSlot,
    UserModel? agent,
    AddressModel? selectedAddress, // Added selectedAddress
  }) async {
    try {
      DateTime bookingDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        timeSlot["time"].hour,
        timeSlot["time"].minute,
      );

      String? selectedImageDownloadUrl;
      String? selectedVideoDownloadUrl;

      try {
        if (selectedImage != null) {
          String fileName =
              'users/${customerData.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          final uploadTask = storageRef.putFile(selectedImage);
          final snapshot = await uploadTask;
          selectedImageDownloadUrl = await snapshot.ref.getDownloadURL();
        }
        if (selectedVideo != null) {
          String fileName =
              'users/${customerData.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          final uploadTask = storageRef.putFile(
            selectedVideo,
            SettableMetadata(contentType: 'video/mp4'),
          );
          final snapshot = await uploadTask;
          selectedVideoDownloadUrl = await snapshot.ref.getDownloadURL();
        }
      } catch (e) {
        debugPrint("Error uploading files: $e");
      }

      final bookingId = AppFirestore.bookingsCollectionRef.doc().id;

      // Create customer data with only the selected address marked as selected
      final updatedCustomerData = CustomerModel(
        role: "customer",
        uid: customerData.uid,
        name: customerData.name,
        email: customerData.email,
        phone: customerData.phone,
        country: customerData.country,
        fcmToken: customerData.fcmToken,
        lanCode: customerData.lanCode,
        favourites: customerData.favourites,
        createdAt: customerData.createdAt,
        updatedAt: customerData.updatedAt,
        isAdmin: customerData.isAdmin,
        addresses: customerData.addresses.map((address) {
          return address.copyWith(
            isSelected: selectedAddress != null
                ? address.id == selectedAddress.id
                : address.isSelected,
          );
        }).toList(),
      );

      bool isOnHour = service.isOnWorkHour(currentTime: DateTime.now());
      bool shouldAutoAssign =
          !isOnHour && (service.category?.isNotEmpty == true);
      BookingModel booking = BookingModel(
        id: bookingId,
        service: service,
        bookingDateTime: Timestamp.fromDate(bookingDate),
        bookingStatusCode: 'P',
        notes: notes.trim(),
        issueImage: selectedImageDownloadUrl ?? "",
        issueVideo: selectedVideoDownloadUrl ?? "",
        customer: updatedCustomerData,
        agent: (isOnHour && agent?.uid?.isNotEmpty == true) ? agent : null,
        selectedAddressId: selectedAddress?.id, // Added selectedAddressId
        isOnHour: isOnHour,
        assignmentScheduledTime: shouldAutoAssign
            ? Timestamp.fromDate(
                bookingDate
                        .subtract(const Duration(hours: 3))
                        .isBefore(DateTime.now())
                    ? DateTime.now().subtract(
                        const Duration(minutes: 5),
                      ) // Set 5 mins back to ensure it triggers
                    : bookingDate.subtract(const Duration(hours: 3)),
              )
            : null,
        autoAssignmentStatus:
            shouldAutoAssign &&
                bookingDate
                    .subtract(const Duration(hours: 3))
                    .isBefore(DateTime.now())
            ? "ready_to_assign"
            : null,
        paymentModeCode: getPaymentModeCode(paymentMode),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // Add the booking to Firestore
      await AppFirestore.bookingsCollectionRef
          .doc(bookingId)
          .set(booking.toJson());

      // If we reach here, the booking was created successfully
      return true;
    } catch (e) {
      debugPrint("Error during booking process: $e");
      return false;
    }
  }

  static Future<bool> saveReview({
    required BookingModel booking,
    required ReviewModel? review,
  }) async {
    try {
      log("Review: ${review?.toJson()}");
      log("Rating: ${review?.rating}");
      final newReview = review?.copyWith(createdAt: Timestamp.now());
      Map<String, dynamic> updateData = {"review": newReview?.toJson() ?? {}};

      if ((review?.tipAmount ?? 0) > 0 &&
          review?.paymentType?.isNotEmpty == true) {
        updateData.addAll({
          'tipAmount': review?.tipAmount,
          'paymentType': review?.paymentType,
          'updatedAt': Timestamp.now(),
        });
      }

      await AppFirestore.bookingsCollectionRef
          .doc(booking.id)
          .update(updateData);

      final userDoc = AppFirestore.usersCollectionRef.doc(booking.agent?.uid);
      final userSnapshot = await userDoc.get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        final oldRating = userData["rating"] ?? 0;
        final newRating = oldRating + review?.rating?.toDouble();
        await userDoc.update({"rating": newRating});
      }

      // Update unified wallet with tip amount (only for full service bookings - mode 1)
      if ((review?.tipAmount ?? 0) > 0 &&
          review?.paymentType?.isNotEmpty == true &&
          booking.completionData?.mode == 1) {
        try {
          final isCashTip = review?.paymentType?.toLowerCase() == 'cash';
          await UnifiedPayoutServices.updateWalletAmounts(
            workerId: booking.agent?.uid ?? '',
            tipsIncrement: review?.tipAmount ?? 0.0,
            isCashTip: isCashTip,
          );
          debugPrint(
            '✅ Unified wallet updated with tip: ${review?.tipAmount} (${isCashTip ? "Cash" : "Card"}) for full service booking',
          );
        } catch (e) {
          debugPrint('❌ Error updating unified wallet with tip: $e');
          // Don't block the review flow if wallet update fails
        }
      }

      return true;
    } catch (e) {
      debugPrint("Error saving review: $e");
      return false;
    }
  }

  static Future<bool> updateBookingStatus({
    BookingModel? booking,
    String? bookingId,
    required bool isCompleted,
    required String paymentModeCode,
    required String orderId,
  }) async {
    try {
      final String? id = booking?.id ?? bookingId;
      if (id == null) {
        debugPrint("Error: No booking ID provided for status update");
        return false;
      }
      await AppFirestore.bookingsCollectionRef.doc(id).update({
        "paymentCompleted": isCompleted,
        "bookingStatusCode": "C",
        "paymentModeCode": paymentModeCode,
        "paymentCompletedAt": Timestamp.now(),
        "orderId": orderId,
        "transactionId": orderId, // Set transactionId same as orderId
        "updatedAt": Timestamp.now(),
        // Apply warranty for 1 week from completion date if it's full work (mode 1)
        if (booking?.completionData?.mode == 1) ...{
          'warranty.expiredOn': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'warranty.updatedAt': FieldValue.serverTimestamp(),
        },
      });
      return true;
    } catch (e) {
      debugPrint("Error updating booking status: $e");
      return false;
    }
  }

  static Future<bool> saveTransaction({
    required TransactionModel transaction,
  }) async {
    try {
      await AppFirestore.transactionRecordsCollectionRef
          .doc(transaction.orderId)
          .set(transaction.toMap());
      return true;
    } catch (e) {
      debugPrint("Error saving transaction: $e");
      return false;
    }
  }

  static Future<bool> saveTipToSubcollection({
    required String workerId,
    required AllTipsModel tipData,
  }) async {
    try {
      // Reference to the subcollection document
      final docRef = AppFirestore.tippingCollectionRef
          .doc(workerId)
          .collection('totalTipsCollectionRef')
          .doc(workerId);

      // Get the document to check if it exists
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        // First time: Create document with initial data
        final documentData = {
          'id': workerId,
          'workerId': workerId,
          'createdAt': Timestamp.now(),
          'tipData': [tipData.toJson()],
        };
        await docRef.set(documentData);
        debugPrint('Tip document created successfully');
      } else {
        // Subsequent calls: Update only tipData array
        await docRef.update({
          "updatedAt": Timestamp.now(),
          'tipData': FieldValue.arrayUnion([tipData.toJson()]),
        });
        debugPrint('Tip added to existing document');
      }

      return true;
    } catch (e) {
      debugPrint('Error saving tip to subcollection: $e');
      return false;
    }
  }

  static Future<bool> saveToTipping({
    required String workerId,
    required TippingModel tipData,
  }) async {
    try {
      await AppFirestore.tippingCollectionRef
          .doc(workerId)
          .set(tipData.toJson());
      return true;
    } catch (e) {
      debugPrint('Error saving tip to collection: $e');
      return false;
    }
  }

  static Future<BookingModel?> getBooking(String bookingId) async {
    try {
      final doc = await AppFirestore.bookingsCollectionRef.doc(bookingId).get();
      if (doc.exists) {
        return BookingModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching booking: $e");
      return null;
    }
  }
}
