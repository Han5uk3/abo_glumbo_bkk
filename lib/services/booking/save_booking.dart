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
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/services/unified_payout_services.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';

class BookingUtils {
  static String getPaymentModeCode(String paymentMode) {
    switch (paymentMode) {
      case "Inside App":
        return "C";
      case "Apple Pay":
        return "A";
      case "Outside App":
        return "O";
      default:
        return "U"; // Unknown
    }
  }

  static Future<String?> saveBooking({
    required ServiceModel service,
    required DateTime selectedDate,
    required String paymentMode,
    required CustomerModel customerData,
    required String notes,
    File? selectedImage,
    File? selectedVideo,
    required Map timeSlot,
    UserModel? agent,
    AddressModel? selectedAddress,
    MatchedServiceZone? serviceLocation,
    String? requestId,
    String? rebookTechnicianId,
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

      bool isOnHour = service.isOnWorkHour(currentTime: bookingDate);
      bool isRebook =
          rebookTechnicianId != null && rebookTechnicianId.isNotEmpty;

      // Auto-assign when no agent is explicitly selected by the customer
      // (the UI already enforces the decision matrix for technician selection vs auto-assign)
      bool shouldAutoAssign =
          !isRebook && (agent == null || agent.uid?.isEmpty != false) && (service.category?.isNotEmpty == true);
      double bookingTimePrice = service.getCurrentPrice(
        currentTime: bookingDate,
      );
      ServiceModel updatedService = service.copyWith(price: bookingTimePrice);

      Timestamp requestCreatedAt = Timestamp.now();
      if (requestId != null) {
        try {
          final docRef = isRebook 
              ? AppFirestore.jobRequestsCollectionRef.doc(requestId)
              : AppFirestore.bookingRequestsCollectionRef.doc(requestId);
              
          final requestDoc = await docRef.get();
          if (requestDoc.exists) {
            final data = requestDoc.data() as Map<String, dynamic>?;
            if (data != null && data['createdAt'] != null) {
              requestCreatedAt = data['createdAt'] as Timestamp;
            }
          }
        } catch (e) {
          debugPrint("Error fetching request createdAt: $e");
        }
      }

      BookingModel booking = BookingModel(
        id: bookingId,
        service: updatedService,
        bookingDateTime: Timestamp.fromDate(bookingDate),
        bookingStatusCode: (agent?.uid?.isNotEmpty == true || (requestId != null && !isRebook)) ? 'A' : 'P',
        notes: notes.trim(),
        issueImage: selectedImageDownloadUrl ?? "",
        issueVideo: selectedVideoDownloadUrl ?? "",
        customer: updatedCustomerData,
        agent: (agent?.uid?.isNotEmpty == true) ? agent : null,
        selectedAddressId: selectedAddress?.id, // Added selectedAddressId
        isOnHour: isOnHour,
        assignmentScheduledTime: shouldAutoAssign
            ? Timestamp.fromDate(
                bookingDate
                        .subtract(const Duration(hours: 2))
                        .isBefore(DateTime.now())
                    ? DateTime.now().subtract(
                        const Duration(minutes: 5),
                      ) // Set 5 mins back to ensure it triggers
                    : bookingDate.subtract(const Duration(hours: 2)),
              )
            : null,
        autoAssignmentStatus: shouldAutoAssign
            ? (bookingDate
                      .subtract(const Duration(hours: 2))
                      .isBefore(DateTime.now())
                  ? "ready_to_assign"
                  : null)
            : (isRebook && requestId == null
                  ? "rebook_pending"
                  : (agent?.uid?.isNotEmpty == true
                        ? "accepted"
                        : null)),
        paymentModeCode: getPaymentModeCode(paymentMode),
        createdAt: requestCreatedAt,
        updatedAt: Timestamp.now(),
        serviceLocation: serviceLocation,
      );

      // If it's a direct assignment or a rebook where technician accepted, status is A
      if (!shouldAutoAssign && agent?.uid?.isNotEmpty == true) {
        booking.bookingStatusCode = 'A';
        booking.assignedAt = booking.createdAt;
        booking.technicianSelectedAt = Timestamp.now();
        booking.acceptedAt = Timestamp.now();
      } else if (requestId != null && !isRebook) {
        booking.bookingStatusCode = 'A';
        booking.assignedAt = booking.createdAt;
        booking.technicianSelectedAt = Timestamp.now();
        booking.acceptedAt = Timestamp.now();
      }

      // Add the booking to Firestore
      await AppFirestore.bookingsCollectionRef.doc(bookingId).set({
        ...booking.toJson(),
        'requestId': requestId,
        'rebookTechnicianId': rebookTechnicianId,
      });

      // If this was from a broadcast request, clean up
      if (requestId != null) {
        final batch = FirebaseFirestore.instance.batch();

        // 1. Update request status
        batch.update(AppFirestore.jobRequestsCollectionRef.doc(requestId), {
          'status': 'finalized',
          'bookingId': bookingId,
        });

        // 2. Mark all offers for this request as closed
        final offers = await AppFirestore.jobOffersCollectionRef
            .where('requestId', isEqualTo: requestId)
            .get();
        for (var doc in offers.docs) {
          batch.update(doc.reference, {'status': 'closed'});
        }

        await batch.commit();

        // 3. Notify the selected technician
        if (agent != null && agent.uid != null) {
          await AppServices.recordTechnicianNotification(
            technicianId: agent.uid!,
            titleEn: 'Job Confirmed',
            titleAr: 'تم تأكيد الطلب',
            bodyEn: 'You have been assigned to a booking.',
            bodyAr: 'لقد تم تعيينك في حجز جديد.',
            type: 'booking_confirmed',
            data: {'bookingId': bookingId},
          );

          // 4. Notify the customer
          await AppServices.recordCustomerNotification(
            customerId: customerData.uid ?? "",
            titleEn: 'Technician Booked',
            titleAr: 'تم حجز فني',
            bodyEn:
                'Technician ${agent.name ?? "A technician"} has been booked successfully.',
            bodyAr: 'تم حجز الفني ${agent.name ?? "فني"} بنجاح.',
            type: 'technician_assigned',
            data: {'bookingId': bookingId},
          );
        }
      }

      // If we reach here, the booking was created successfully
      return bookingId;
    } catch (e) {
      debugPrint("Error during booking process: $e");
      return null;
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

      // Update unified wallet with tip amount
      if ((review?.tipAmount ?? 0) > 0 &&
          review?.paymentType?.isNotEmpty == true) {
        try {
          final isCashTip = review?.paymentType?.toLowerCase() == 'cash';
          await UnifiedPayoutServices.updateWalletAmounts(
            workerId: booking.agent?.uid ?? '',
            tipsIncrement: review?.tipAmount ?? 0.0,
            isCashTip: isCashTip,
          );
          debugPrint(
            '✅ Unified wallet updated with tip: ${review?.tipAmount} (${isCashTip ? "Cash" : "Card"})',
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
      final bool isOutsideApp = paymentModeCode == "O";

      await AppFirestore.bookingsCollectionRef.doc(id).update({
        "paymentCompleted": isOutsideApp ? false : isCompleted,
        "bookingStatusCode": isOutsideApp ? "VP" : "C",
        "paymentModeCode": paymentModeCode,
        "paymentCompletedAt": Timestamp.now(),
        "orderId": orderId,
        "transactionId": orderId, // Set transactionId same as orderId
        "updatedAt": Timestamp.now(),
        "completionData.paymentMethod": paymentModeCode == "C"
            ? "Inside App"
            : "Outside App",
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

  static Future<String?> saveBookingRequest({
    required ServiceModel service,
    required DateTime selectedDate,
    required String paymentMode,
    required CustomerModel customerData,
    required String notes,
    File? selectedImage,
    File? selectedVideo,
    required Map timeSlot,
    AddressModel? selectedAddress,
    MatchedServiceZone? serviceLocation,
    List<String>? rejectedTechnicianUids,
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

      final bookingId = AppFirestore.bookingRequestsCollectionRef.doc().id;

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

      bool isOnHour = service.isOnWorkHour(currentTime: bookingDate);
      double bookingTimePrice = service.getCurrentPrice(currentTime: bookingDate);
      ServiceModel updatedService = service.copyWith(price: bookingTimePrice);

      final Map<String, dynamic> requestData = {
        'id': bookingId,
        'service': updatedService.toJson(),
        'bookingDateTime': Timestamp.fromDate(bookingDate),
        'notes': notes.trim(),
        'issueImage': selectedImageDownloadUrl ?? "",
        'issueVideo': selectedVideoDownloadUrl ?? "",
        'customer': updatedCustomerData.toJson(),
        'paymentModeCode': getPaymentModeCode(paymentMode),
        'selectedAddressId': selectedAddress?.id,
        'isOnHour': isOnHour,
        'serviceLocation': serviceLocation?.toJson(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'status': 'searching',
        'acceptedTechnicians': [],
        'rejectedTechnicians': rejectedTechnicianUids ?? [],
      };

      await AppFirestore.bookingRequestsCollectionRef.doc(bookingId).set(requestData);
      return bookingId;
    } catch (e) {
      debugPrint("Error saving booking request: $e");
      return null;
    }
  }

  static Future<String?> saveAutoAssignmentRequest({
    required ServiceModel service,
    required DateTime selectedDate,
    required String paymentMode,
    required CustomerModel customerData,
    required String notes,
    File? selectedImage,
    File? selectedVideo,
    required Map timeSlot,
    AddressModel? selectedAddress,
    MatchedServiceZone? serviceLocation,
    List<String>? cancelledWorkerUids,
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

      bool isOnHour = service.isOnWorkHour(currentTime: bookingDate);
      double bookingTimePrice = service.getCurrentPrice(currentTime: bookingDate);
      ServiceModel updatedService = service.copyWith(price: bookingTimePrice);

      // Create standard booking model with status 'P' and no technician
      BookingModel booking = BookingModel(
        id: bookingId,
        service: updatedService,
        bookingDateTime: Timestamp.fromDate(bookingDate),
        bookingStatusCode: 'P',
        notes: notes.trim(),
        issueImage: selectedImageDownloadUrl ?? "",
        issueVideo: selectedVideoDownloadUrl ?? "",
        customer: updatedCustomerData,
        agent: null,
        selectedAddressId: selectedAddress?.id,
        isOnHour: isOnHour,
        paymentModeCode: getPaymentModeCode(paymentMode),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        serviceLocation: serviceLocation,
        autoAssignmentStatus: 'ready_to_assign',
        cancelledWorkerUids: cancelledWorkerUids,
      );

      // Save to standard bookings
      await AppFirestore.bookingsCollectionRef.doc(bookingId).set(booking.toJson());

      // Save to auto-assignment_requests
      final bool isInstant = bookingDate.difference(DateTime.now()).inMinutes <= 180;
      final Map<String, dynamic> autoReqData = {
        'id': bookingId,
        'service': updatedService.toJson(),
        'bookingDateTime': Timestamp.fromDate(bookingDate),
        'notes': notes.trim(),
        'issueImage': selectedImageDownloadUrl ?? "",
        'issueVideo': selectedVideoDownloadUrl ?? "",
        'customer': updatedCustomerData.toJson(),
        'paymentModeCode': getPaymentModeCode(paymentMode),
        'selectedAddressId': selectedAddress?.id,
        'isOnHour': isOnHour,
        'serviceLocation': serviceLocation?.toJson(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'status': 'P',
        'type': isInstant ? 'instant' : 'late',
        'notificationSent': false,
        'agent': null,
      };

      if (cancelledWorkerUids != null && cancelledWorkerUids.isNotEmpty) {
        autoReqData['cancelledWorkerUids'] = cancelledWorkerUids;
      }

      await AppFirestore.autoAssignmentRequestsCollectionRef.doc(bookingId).set(autoReqData);
      return bookingId;
    } catch (e) {
      debugPrint("Error saving auto assignment request: $e");
      return null;
    }
  }
}
