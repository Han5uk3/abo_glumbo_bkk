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
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
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
    final inspectionFee = widget.booking?.completionData?.inspectionFee ?? 0.0;
    final discountedInspectionFee =
        widget.service?.getDiscountedPrice(inspectionFee) ??
        widget.booking?.service.getDiscountedPrice(inspectionFee) ??
        inspectionFee;
    final serviceCost = widget.booking?.completionData?.totalCost ?? 0.0;
    final amount = widget.booking?.completionData != null
        ? (serviceCost + discountedInspectionFee)
        : (widget.service
                  ?.getDiscountedPrice(widget.service!.getCurrentPrice())
                  .toDouble() ??
              0.00);

    String? invoiceId;
    if (widget.isFromBooking &&
        widget.booking != null &&
        widget.customerData.uid != null) {
      invoiceId =
          '${widget.booking!.newBookingId ?? widget.booking!.id}_${widget.customerData.uid}';
    }

    TransactionModel transaction = TransactionModel(
      Timestamp.now(),
      amount: amount,
      paymentStatus: "completed",
      paymentMethod: widget.selectedPayment ?? "Inside App",
      createdAt: Timestamp.now(),
      orderId: widget.orderId,
      customerId: widget.customerData.uid ?? "",
      workerId: widget.booking?.agent?.uid ?? widget.agent?.uid ?? "",
      bookingId: bookingId ?? widget.booking?.id ?? "",
      invoiceId: invoiceId,
    );
    bool saved = await BookingUtils.saveTransaction(transaction: transaction);



    return saved;
  }

  Future<bool> saveBooking() async {
    return await BookingUtils.updateBookingStatus(
      booking: widget.booking,
      paymentModeCode: widget.selectedPayment == "Inside App" ? "C" : "O",
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
            paymentMethod: "Inside App",
            id: "id_${DateTime.now().millisecondsSinceEpoch}",
          ),
        );
      }

      if (widget.booking != null) {
        final success = await BookingUtils.saveReview(
          booking: widget.booking!,
          review: widget.review?.copyWith(isTipPaid: true),
        );
        return success;
      } else {
        if (widget.review?.workerId != null &&
            (widget.review?.tipAmount ?? 0) > 0) {
          await UnifiedPayoutServices.updateWalletAmounts(
            workerId: widget.review!.workerId!,
            tipsIncrement: widget.review!.tipAmount!,
            isCashTip: false,
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error saving review: $e');
      return false;
    }
  }

  Future<void> _processPaymentAndBooking() async {
    if (widget.isFromBooking && widget.booking != null) {
      await saveBooking();
      await saveTransaction();

      // The technician's unified wallet is credited server-side by the
      // `creditTechnicianWalletOnPaymentCompletion` Cloud Function. Crediting it
      // from here as well double-counted every in-app payment against the Cloud
      // Function that was already doing it, and on a different basis
      // (serviceCost + inspectionFee here vs totalCost everywhere else, so the
      // manual wallet re-sync then disagreed with both).
    } else if (!widget.isFromBooking) {
      await saveReview();
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSuccessPage(
          isFromBooking: widget.isFromBooking,
          amount: widget.isFromBooking
              ? (widget.booking?.completionData != null
                    ? ((widget.booking!.completionData?.totalCost ?? 0.0) +
                          (widget.service?.getDiscountedPrice(
                                widget.booking!.completionData?.inspectionFee ??
                                    0.0,
                              ) ??
                              widget.booking!.service.getDiscountedPrice(
                                widget.booking!.completionData?.inspectionFee ??
                                    0.0,
                              ) ??
                              widget.booking!.completionData?.inspectionFee ??
                              0.0))
                    : (widget.service
                              ?.getDiscountedPrice(widget.service!.getCurrentPrice())
                              .toDouble() ??
                          0.00))
              : widget.review?.tipAmount ?? 0.00,
          orderId: widget.orderId,
          booking: widget.booking,
          bookingId: widget.booking?.id ?? _newBookingId,
          bookingDate:
              widget.booking?.bookingDateTime.toDate() ?? widget.selectedDate,
          service: widget.booking?.service ?? widget.service,
          paymentMethod: "Inside App",
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.finalizingBookingInfo ??
                  "Please wait while we finalize your booking...",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
