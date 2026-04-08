import 'dart:developer';
import 'dart:io';

import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/total_tip.dart';
import 'package:abo_glumbo_bbk/models/transaction.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/payment_success.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/services/unified_payout_services.dart';
import 'package:abo_glumbo_bbk/services/booking/add_booking.dart.dart';
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProcessingPaymentPage extends StatefulWidget {
  final CustomerModel customerData;
  final bool isFromBooking;
  final File? selectedImage;
  final File? selectedVideo;
  final DateTime? selectedDate;
  final Map? timeSlot;
  final ServiceModel? service;
  final ReviewModel? review;
  final BookingModel? booking;
  final UserModel? agent;
  final AddressModel? selectedAddress;
  final MatchedServiceZone? serviceLocation;
  final TextEditingController? notesController;
  final String? selectedPayment;
  final String orderId;

  const ProcessingPaymentPage({
    super.key,
    required this.customerData,
    required this.isFromBooking,
    required this.orderId,
    this.selectedImage,
    this.selectedVideo,
    this.selectedDate,
    this.timeSlot,
    this.service,
    this.review,
    this.booking,
    this.agent,
    this.selectedAddress,
    this.serviceLocation,
    this.notesController,
    this.selectedPayment,
  });

  @override
  State<ProcessingPaymentPage> createState() => _ProcessingPaymentPageState();
}

class _ProcessingPaymentPageState extends State<ProcessingPaymentPage> {
  String? _newBookingId;

  @override
  void initState() {
    super.initState();
    _processPaymentAndBooking();
  }

  Future<bool> saveTransaction({String? bookingId}) async {
    final amount =
        double.tryParse(
          widget.booking?.completionData?.totalCost.toString() ??
              widget.service?.price.toString() ??
              '0.00',
        ) ??
        0.00;

    TransactionModel transaction = TransactionModel(
      Timestamp.now(),
      amount: amount,
      paymentStatus: "completed",
      paymentMethod: widget.selectedPayment ?? "Cards",
      createdAt: Timestamp.now(),
      orderId: widget.orderId,
      customerId: widget.customerData.uid ?? "",
      workerId: widget.booking?.agent?.uid ?? widget.agent?.uid ?? "",
      bookingId: bookingId ?? widget.booking?.id ?? "",
    );
    return await BookingUtils.saveTransaction(transaction: transaction);
  }

  Future<void> _createBookingAndConfirm() async {
    if (widget.booking != null) {
      await saveBooking();
      await saveTransaction();
      return;
    }

    try {
      final bookingId = await NewBookingUtils.addBooking(
        service: widget.service!,
        selectedDate: widget.selectedDate!,
        customerData: widget.customerData,
        notes: widget.notesController?.text ?? "",
        selectedImage: widget.selectedImage,
        selectedVideo: widget.selectedVideo,
        timeSlot: widget.timeSlot!,
        agent: widget.agent!,
        selectedAddress: widget.selectedAddress,
        serviceLocation: widget.serviceLocation,
      );

      if (bookingId != null) {
        await BookingUtils.updateBookingStatus(
          bookingId: bookingId,
          paymentModeCode: widget.selectedPayment == "Cards" ? "C" : "O",
          isCompleted: true,
          orderId: widget.orderId,
        );
        _newBookingId = bookingId;
        await saveTransaction(bookingId: bookingId);
        log('✅ Booking created and confirmed: $bookingId');
      } else {
        log('❌ Failed to create booking after successful payment');
      }
    } catch (e) {
      log('❌ Error creating booking: $e');
    }
  }

  Future<bool> saveBooking() async {
    return await BookingUtils.updateBookingStatus(
      booking: widget.booking,
      paymentModeCode: widget.selectedPayment == "Cards" ? "C" : "O",
      isCompleted: true,
      orderId: widget.orderId,
    );
  }

  Future<bool> saveReview() async {
    try {
      if (widget.review?.workerId != null) {
        await BookingUtils.saveTipToSubcollection(
          workerId: widget.review?.workerId ?? "",
          tipData: AllTipsModel(
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
            totalTipAmount: widget.review?.tipAmount,
            proofs: [],
            agentId: widget.review?.workerId,
            paymentMethod: "cards",
            id: "id_${DateTime.now().millisecondsSinceEpoch}",
          ),
        );
      }

      final success = await BookingUtils.saveReview(
        booking: widget.booking!,
        review: widget.review?.copyWith(isTipPaid: true),
      );

      return success;
    } catch (e) {
      debugPrint('Error saving review: $e');
      return false;
    }
  }

  Future<void> _processPaymentAndBooking() async {
    if (widget.isFromBooking) {
      if (widget.booking != null) {
        await saveBooking();
        await saveTransaction();

        try {
          final amount =
              double.tryParse(
                widget.booking?.completionData?.totalCost.toString() ?? '0.00',
              ) ??
              0.00;
          await UnifiedPayoutServices.updateWalletAmounts(
            workerId: widget.booking?.agent?.uid ?? '',
            earningsIncrement: amount,
          );
          debugPrint('✅ Unified wallet updated with earnings: $amount');
        } catch (e) {
          debugPrint('❌ Error updating unified wallet: $e');
        }
      } else {
        // New Deferred Flow
        await _createBookingAndConfirm();
      }
    } else {
      await saveReview();
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSuccessPage(
          isFromBooking: widget.isFromBooking,
          amount: widget.isFromBooking
              ? (widget.booking != null
                    ? (double.tryParse(
                            widget.booking?.completionData?.totalCost
                                    .toString() ??
                                '0.00',
                          ) ??
                          0.00)
                    : (widget.service
                              ?.getDiscountedPrice(widget.service?.price ?? 0.0)
                              .toDouble() ??
                          0.00))
              : widget.review?.tipAmount ?? 0.00,
          orderId: widget.orderId,
          booking: widget.booking,
          bookingId: widget.booking?.id ?? _newBookingId,
          bookingDate:
              widget.booking?.bookingDateTime.toDate() ?? widget.selectedDate,
          service: widget.booking?.service ?? widget.service,
          paymentMethod: "Cards",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              child: Loader(color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)?.processingPayment ??
                  "Processing payment...",
              style: DMSansFont.textStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.finalizingBookingInfo ??
                  "Please wait while we finalize your booking...",
              style: DMSansFont.textStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
