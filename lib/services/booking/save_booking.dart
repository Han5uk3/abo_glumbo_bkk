import 'dart:developer';
import 'dart:io';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
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
    required UserModel agent,
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
        location: customerData.location,
        favourites: customerData.favourites,
        createdAt: customerData.createdAt,
        updatedAt: customerData.updatedAt,
        isAdmin: customerData.isAdmin,
        detailedLocation: customerData.detailedLocation,
        addresses: customerData.addresses.map((address) {
          return address.copyWith(isSelected: address.isSelected);
        }).toList(),
      );

      BookingModel booking = BookingModel(
        id: bookingId,
        service: service,
        bookingDateTime: Timestamp.fromDate(bookingDate),
        bookingStatusCode: 'P',
        notes: notes.trim(),
        issueImage: selectedImageDownloadUrl ?? "",
        issueVideo: selectedVideoDownloadUrl ?? "",
        customer: updatedCustomerData,
        agent: agent,

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

      return true;
    } catch (e) {
      debugPrint("Error saving review: $e");
      return false;
    }
  }

  static Future<bool> updateBookingStatus({
    required BookingModel booking,
    required bool isCompleted,
    required String paymentModeCode,
    required String orderId,
  }) async {
    try {
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        "paymentCompleted": isCompleted,
        "paymentModeCode": paymentModeCode,
        "orderId": orderId,
        "updatedAt": Timestamp.now(),
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

  static Future<bool> updateBalance({
    required String? workerId,
    required double amount,
  }) async {
    try {
      if (workerId == null) return false;
      final user = AppFirestore.usersCollectionRef.doc(workerId).get();
      final balance = (await user).get("availableBalance");
      balance == null
          ? await AppFirestore.usersCollectionRef.doc(workerId).update({
              "availableBalance": amount,
            })
          : await AppFirestore.usersCollectionRef.doc(workerId).update({
              "availableBalance": FieldValue.increment(amount),
            });

      return true;
    } catch (e) {
      debugPrint("Error updating balance: $e");
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
}
