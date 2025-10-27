import 'dart:io';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
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
        districtName: customerData.districtName,
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
      Map<String, dynamic> updateData = {"review": review?.toJson() ?? {}};

      if ((review?.tipAmount ?? 0) > 0 &&
          review?.paymentType?.isNotEmpty == true) {
        updateData.addAll({
          'tipAmount': review?.tipAmount,
          'paymentType': review?.paymentType,
          'createdAt': Timestamp.now(),
        });
      }

      await AppFirestore.bookingsCollectionRef
          .doc(booking.id)
          .update(updateData);

      final userDoc = AppFirestore.usersCollectionRef.doc(booking.agent?.uid);
      final userSnapshot = await userDoc.get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        final newRating = userData["rating"] + review?.rating.toDouble();
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
  }) async {
    try {
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        "paymentCompleted": isCompleted,
        "paymentModeCode": paymentModeCode,
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
      await AppFirestore.transactionRecordsCollectionRef.doc(transaction.orderId).set(transaction.toMap());
      return true;
    } catch (e) {
      debugPrint("Error saving transaction: $e");
      return false;
    }
  }
      
   
}
