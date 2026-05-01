import 'dart:developer';

import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/date_formatter.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/booking_bloc.dart';

import 'package:abo_glumbo_bbk/pages/bookings/booking_details_page.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/sheets/cancel_booking_dialog.dart';
import 'package:abo_glumbo_bbk/sheets/upload_payment_proof_sheet.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:intl/intl.dart' show DateFormat;

class ServiceBookingTile extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onRefresh;
  final VoidCallback onReviewButtonPressed;
  final bool isWarranty;

  const ServiceBookingTile({
    super.key,
    required this.booking,
    required this.onRefresh,
    required this.onReviewButtonPressed,
    this.isWarranty = false,
  });

  @override
  Widget build(BuildContext context) {
    AddressModel? customerSelectedAddress = booking.customer.addresses.isEmpty
        ? null
        : booking.customer.addresses.firstWhere(
            (address) => address.isSelected ?? false,
            orElse: () => booking.customer.addresses.first,
          );

    final localization = AppLocalizations.of(context)!;

    TextEditingController reasonController = TextEditingController();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailsPage(
            booking: booking,
            onRefresh: onRefresh,
            isWarranty: isWarranty,
          ),
        ),
      ),
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
        padding: EdgeInsets.all(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xffEAF1FF).withOpacity(0.50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child:
                            (booking.service.image != null &&
                                booking.service.image!.isNotEmpty &&
                                Uri.tryParse(booking.service.image!) != null &&
                                Uri.tryParse(
                                  booking.service.image!,
                                )!.hasAbsolutePath)
                            ? CachedNetworkImage(
                                imageUrl: booking.service.image!,
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.broken_image_outlined),
                              )
                            : Container(
                                height: 50,
                                width: 50,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Wrap(
                              children: [
                                Text(
                                  "#${booking.id}",
                                  style: TextStyle(fontSize: 9),
                                ),
                                Text(
                                  booking.service.nameLocalized(
                                        languageCode:
                                            AppLocalizations.of(
                                              context,
                                            )?.localeName ??
                                            'en',
                                      ) ??
                                      '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: DMSansFont.textStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),

                            // Text(
                            //   booking.service.descriptionLocalized(
                            //         languageCode:
                            //             AppLocalizations.of(context)?.localeName ??
                            //             'en',
                            //       ) ??
                            //       '',
                            //   style: DMSansFont.textStyle(
                            //     color: Colors.black45,
                            //     fontSize: 12,
                            //   ),
                            //   maxLines: 4,
                            //   overflow: TextOverflow.ellipsis,
                            // ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${(booking.bookingStatusCode == "C" || booking.bookingStatusCode == "VP") ? ((booking.completionData?.totalCost ?? 0) + (booking.service.getDiscountedPrice(booking.service.price ?? 0))).toStringAsFixed(1) : booking.service.getDiscountedPrice(booking.service.price ?? 0).toStringAsFixed(1)} ${AppLocalizations.of(context)!.sar}",
                            style: DMSansFont.textStyle(
                              color: AppColors.green1,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),

                  SizedBox(height: 10),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isWarranty && _shouldShowComplaintButton())
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () async {
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          actionsAlignment: MainAxisAlignment.start,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.submitComplaint,
                                  style: DMSansFont.textStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            )!.escalateWarrantyConfirmation,
                            style: DMSansFont.textStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          actions: [
                            eButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              context: context,
                              backgroundColor: Colors.grey,
                              text: AppLocalizations.of(context)!.cancel,
                              textColor: Colors.white,
                            ),

                            eButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              context: context,
                              backgroundColor: AppColors.primary,
                              text: AppLocalizations.of(context)!.yes,
                              textColor: Colors.white,

                              widget: Text(
                                AppLocalizations.of(context)!.yes,
                                style: DMSansFont.textStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );

                    // If user confirmed, proceed with escalation
                    if (confirmed == true) {
                      try {
                        // Update booking document with isEscalated: true
                        await AppFirestore.bookingsCollectionRef
                            .doc(booking.id)
                            .update({
                              'isEscalated': true,
                              'escalatedAt': Timestamp.now(),
                            });

                        if (context.mounted) {
                          showSnackBar(
                            AppLocalizations.of(
                              context,
                            )!.complaintSubmittedSuccessfully,
                            context,
                            backgroundColor: Colors.green,
                          );
                          // Refresh the page to reflect changes
                          onRefresh.call();
                        }
                      } catch (e) {
                        log('Error escalating complaint: $e');
                        if (context.mounted) {
                          showSnackBar(
                            "${AppLocalizations.of(context)!.error}: $e",
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.submitComplaint,
                        style: DMSansFont.textStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.bgWhite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Wrap(
            //   alignment: WrapAlignment.start,
            //   children: [
            if (customerSelectedAddress != null &&
                customerSelectedAddress.buildingNumber.isNotEmpty)
              // _buildSectionCards(
              //   context: context,
              //   hasChat: false,
              // // title: localization.location,
              // icon: Icons.location_on_rounded,
              // children: [
              // _buildInfoRow(
              //   localization.address,
              //   customerSelectedAddress.buildingNumber,
              // ),
              _buildInfoRow(
                localization.location,
                customerSelectedAddress.streetName ?? 'N/A',
                icon: Icon(Icons.location_on_outlined),
                //     ),
                //   ],
                // ),
                // ],
              ),

            //   ],
            // ),
            Divider(thickness: 0.5, color: Color(0xffCAC4D0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildTimestampText(context)),
                        if (!isWarranty &&
                            (booking.bookingStatusCode == "C" ||
                                booking.bookingStatusCode == "CP" ||
                                booking.bookingStatusCode == "VP"))
                          _buildBookingActionButtons(context),
                        if (isWarranty) _buildWarrantyStatusBadge(context),
                      ],
                    ),
                  ),

                  if (booking.bookingStatusCode == "C" ||
                      booking.bookingStatusCode == "VP")
                    const SizedBox.shrink()
                  else if (booking.bookingStatusCode == "P")
                    SizedBox(
                      height: 23,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xffE74C3C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide.none, // This removes the border
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () async {
                          final bookingBloc = context.read<BookingBloc>();
                          bool? res = await showBookingCancelDialog(
                            context,
                            booking: booking,
                            controller: reasonController,
                          );
                          if (res == true) {
                            bookingBloc.add(
                              CancelBookingEvent(
                                booking,
                                reasonController.text.trim(),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.green,
                                content: Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.bookingCancelled ??
                                      '',
                                ),
                              ),
                            );
                            // refresh the page
                            onRefresh.call();
                          }
                        },
                        child: Text(
                          AppLocalizations.of(context)?.cancel ?? '',
                          style: DMSansFont.textStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 8,
                            color: AppColors.bgWhite,
                          ),
                        ),
                      ),
                    )
                  else if (booking.bookingStatusCode == "C" &&
                      booking.paymentCompleted == true &&
                      !isWarranty)
                    Container(
                      height: 23,
                      decoration: BoxDecoration(
                        // border: Border.all(color: AppColors.green2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)?.completed ?? '',
                        style: DMSansFont.textStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 8,
                          color: AppColors.green2,
                        ),
                      ),
                    )
                  else if (booking.bookingStatusCode == "X" ||
                      booking.bookingStatusCode == "XC")
                    Container(
                      height: 23,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.red),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)?.canceled ?? '',
                        style: DMSansFont.textStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 8,
                          color: AppColors.red,
                        ),
                      ),
                    )
                  else if (booking.bookingStatusCode == "R") ...{
                    Container(
                      height: 23,

                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.darkGrey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)?.rejected ?? '',
                        style: DMSansFont.textStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 8,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ),
                  } else if (isWarranty) ...{
                    const SizedBox.shrink(),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampText(BuildContext context) {
    if (isWarranty) {
      return _buildWarrantyTimestamp(context);
    }
    return _buildBookingTimestamp(context);
  }

  Widget _buildBookingTimestamp(BuildContext context) {
    final locale = AppLocalizations.of(context)?.localeName ?? 'en';

    if (booking.bookingStatusCode == "P" && booking.createdAt != null) {
      return _timestampText(
        "${AppLocalizations.of(context)!.bookedOn} : ${formatBookingDateTime(booking.createdAt!.toDate(), locale)}",
      );
    }

    if (booking.acceptedAt != null && booking.bookingStatusCode == "A") {
      return _timestampText(
        "${AppLocalizations.of(context)!.acceptedOn} : ${formatBookingDateTime(booking.acceptedAt!.toDate(), locale)}",
      );
    }

    if (booking.completedAt != null && booking.bookingStatusCode == "C") {
      return _timestampText(
        "${AppLocalizations.of(context)!.completedOn} : ${formatBookingDateTime(booking.completedAt!.toDate(), locale)}",
      );
    }

    if (booking.bookingStatusCode == "VP" && booking.paidAt != null) {
      return _timestampText(
        "${AppLocalizations.of(context)!.paidOn} : ${formatBookingDateTime(booking.paidAt!.toDate(), locale)}",
      );
    }

    if (booking.bookingStatusCode == "X" ||
        booking.bookingStatusCode == "XC" ||
        booking.bookingStatusCode == "R") {
      if (booking.bookingStatusCode != "R") {
        return _timestampText(
          "${AppLocalizations.of(context)!.cancelledOn} : ${formatBookingDateTime(booking.cancelledAt!.toDate(), locale)}",
        );
      }
      return _timestampText(
        "${AppLocalizations.of(context)!.rejectedOn} : ${formatBookingDateTime(booking.rejectedAt!.toDate(), locale)}",
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildWarrantyTimestamp(BuildContext context) {
    final warranty = booking.warranty;
    if (warranty == null) return SizedBox.shrink();

    final locale = AppLocalizations.of(context)?.localeName ?? 'en';
    final statusCode = warranty.warrantyStatusCode;

    final timestampMap = {
      "A": (warranty.createdAt != null)
          ? "${AppLocalizations.of(context)!.warrantyAppliedOn} : ${formatBookingDateTime(warranty.createdAt!, locale)}"
          : null,
      "C": (warranty.completedAt != null)
          ? "${AppLocalizations.of(context)!.completedOn} : ${formatBookingDateTime(warranty.completedAt!, locale)}"
          : null,
      "E": (warranty.expiredOn != null)
          ? "${AppLocalizations.of(context)!.expiredOn} : ${formatBookingDateTime(warranty.expiredOn!, locale)}"
          : null,
      "X": (warranty.rejectedAt != null)
          ? "${AppLocalizations.of(context)!.rejectedOn} : ${formatBookingDateTime(warranty.rejectedAt!, locale)}"
          : null,
      "R": (warranty.requestedOn != null)
          ? "${AppLocalizations.of(context)!.requestedOn} : ${formatBookingDateTime(warranty.requestedOn!, locale)}"
          : null,
      "S": (warranty.acceptedAt != null)
          ? "${AppLocalizations.of(context)!.acceptedOn} : ${formatBookingDateTime(warranty.acceptedAt!, locale)}"
          : null,
    };

    final text = timestampMap[statusCode];
    return text != null ? _timestampText(text) : SizedBox.shrink();
  }

  Widget _timestampText(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_month, size: 19, color: AppColors.black1),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.black1, fontSize: 8.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingActionButtons(BuildContext context) {
    if (booking.bookingStatusCode == "VP") {
      return _buildVerificationBadge(context);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((booking.bookingStatusCode == "C" || booking.bookingStatusCode == "CP") &&
            booking.paymentCompleted == false)
          _buildPaymentButton(context),
        if (booking.paymentCompleted == true) _buildReviewButton(context),
      ],
    );
  }

  Widget _buildVerificationBadge(BuildContext context) {
    return Container(
      height: 23,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        AppLocalizations.of(context)?.verificationPending.toUpperCase() ??
            'VERIFICATION PENDING',
        style: DMSansFont.textStyle(
          fontWeight: FontWeight.w500,
          fontSize: 8,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildPaymentButton(BuildContext context) {
    final bool isAppPayment = booking.paymentModeCode == 'C';

    return GestureDetector(
      onTap: () async {
        if (isAppPayment) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentWebView(
                isFromBooking: true,
                customerData: booking.customer,
                service: booking.service,
                booking: booking,
                selectedPayment: "Cards",
              ),
            ),
          );
        } else {
          final result = await showUploadPaymentProofSheet(
            context,
            booking: booking,
          );
          if (result == true) {
            // Refresh the page to show updated status
            onRefresh.call();
          }
        }
      },
      child: SizedBox(
        height: 23,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            (isAppPayment
                    ? AppLocalizations.of(context)!.completePayment
                    : AppLocalizations.of(context)?.paymentPending ??
                        'Payment Pending')
                .toUpperCase(),
            style: DMSansFont.textStyle(
              fontWeight: FontWeight.w500,
              fontSize: 8,
              color: Colors.orange,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewButton(BuildContext context) {
    return SizedBox(
      height: 23,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: AppColors.yellow,
        ),
        onPressed: booking.review == null ? onReviewButtonPressed : null,
        child: Text(
          booking.review == null
              ? AppLocalizations.of(context)?.writeAReview ?? ''
              : AppLocalizations.of(context)?.reviewSubmitted ?? '',
          style: DMSansFont.textStyle(
            color: Colors.black,
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWarrantyStatusBadge(BuildContext context) {
    final warranty = booking.warranty;
    if (warranty == null) return SizedBox.shrink();

    final statusCode = warranty.warrantyStatusCode;

    switch (statusCode) {
      case "A":
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.repairUnderWarranty ?? '',
          color: AppColors.primary,
          textColor: Colors.white,
          onTap: () => showWarrantyClaimedBottomSheet(context, booking),
        );
      case "E":
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.expired ?? '',
          color: Colors.grey,
          textColor: Colors.grey,
          borderOnly: true,
        );
      case "R":
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.requested ?? '',
          color: Colors.orange,
          textColor: Colors.orange,
          borderOnly: true,
        );
      case "S":
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.accepted ?? '',
          color: AppColors.secondary,
          textColor: AppColors.secondary,
          borderOnly: true,
        );
      case "C":
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.completed ?? '',
          color: Colors.green,
          textColor: Colors.green,
          borderOnly: true,
        );
      case "X":
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.rejected ?? '',
          color: Colors.red,
          textColor: Colors.red,
          borderOnly: true,
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildWarrantyBadge({
    required String label,
    required Color color,
    required Color textColor,
    bool borderOnly = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 23,
        child: Container(
          decoration: BoxDecoration(
            color: borderOnly ? Colors.white : color,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: DMSansFont.textStyle(
              fontWeight: FontWeight.w500,
              fontSize: 8,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  void showWarrantyClaimedBottomSheet(
    BuildContext context,
    BookingModel booking,
  ) {
    final daysLeft = calculateDaysLeft();
    final isExpiringSoon = daysLeft <= 2;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Header with Gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1E88E5).withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )?.requestRepairUnderWarranty ??
                                    '',
                                style: DMSansFont.textStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                booking.service.nameLocalized(
                                      languageCode:
                                          AppLocalizations.of(
                                            context,
                                          )?.localeName ??
                                          'en',
                                    ) ??
                                    '',
                                style: DMSansFont.textStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Days Left Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isExpiringSoon
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isExpiringSoon
                              ? Colors.orange.shade200
                              : Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpiringSoon
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded,
                            color: isExpiringSoon
                                ? Colors.orange.shade100
                                : Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),

                          Text(
                            '$daysLeft ${daysLeft == 1 ? AppLocalizations.of(context)?.dayLeft ?? '' : AppLocalizations.of(context)?.daysLeft ?? ''}',
                            style: DMSansFont.textStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // What's Covered Section
                      _buildSectionCard(
                        context: context,
                        icon: Icons.check_circle_rounded,
                        iconColor: Color(0xFF4CAF50),
                        iconBgColor: Color(0xFF4CAF50).withOpacity(0.1),
                        title: AppLocalizations.of(context)?.whatsCovered ?? '',
                        titleColor: Color(0xFF2E7D32),
                        items: [
                          AppLocalizations.of(context)?.issueone ?? '',
                          AppLocalizations.of(context)?.issuetwo ?? '',
                          AppLocalizations.of(context)?.issuethree ?? '',
                          AppLocalizations.of(context)?.issuefour ?? '',
                        ],
                        gradientColors: [
                          Color(0xFF4CAF50).withOpacity(0.05),
                          Color(0xFF81C784).withOpacity(0.05),
                        ],
                      ),

                      SizedBox(height: 16),

                      // What's NOT Covered Section
                      _buildSectionCard(
                        context: context,
                        icon: Icons.cancel_rounded,
                        iconColor: Color(0xFFE53935),
                        iconBgColor: Color(0xFFE53935).withOpacity(0.1),
                        title:
                            AppLocalizations.of(context)?.whatsNotCovered ?? '',
                        titleColor: Color(0xFFC62828),
                        items: [
                          AppLocalizations.of(context)?.notissueone ?? '',
                          AppLocalizations.of(context)?.notissuetwo ?? '',
                          AppLocalizations.of(context)?.notissuethree ?? '',
                          AppLocalizations.of(context)?.notissuefour ?? '',
                          AppLocalizations.of(context)?.notissuefive ?? '',
                        ],
                        gradientColors: [
                          Color(0xFFE53935).withOpacity(0.05),
                          Color(0xFFEF5350).withOpacity(0.05),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Important Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF2196F3).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF2196F3).withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF2196F3).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_rounded,
                                size: 24,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.importantInformation ??
                                        '',
                                    style: DMSansFont.textStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    AppLocalizations.of(context)?.claimText ??
                                        '',
                                    style: DMSansFont.textStyle(
                                      fontSize: 13,
                                      color: Color(0xFF424242),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF66BB6A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF4CAF50).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await AppFirestore.bookingsCollectionRef
                                        .doc(booking.id)
                                        .update({
                                          'warranty.warrantyStatusCode': 'R',
                                          'warranty.updatedAt': Timestamp.now(),
                                          'warranty.claimrequested': true,
                                          'warranty.requestedOn':
                                              Timestamp.now(),
                                          'warranty.assignedTechnicianId':
                                              booking.agent!.uid,
                                        });
                                    showSnackBar(
                                      AppLocalizations.of(
                                        context,
                                      )!.repairRequestedSuccessfully,
                                      context,
                                      backgroundColor: Colors.green,
                                    );
                                    Navigator.pop(context);
                                  } catch (e) {
                                    log(e.toString());
                                    Navigator.pop(context);
                                    showSnackBar(
                                      "${AppLocalizations.of(context)!.error} : $e",
                                      context,
                                      backgroundColor: Colors.red,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.build_circle_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.requestRepair ??
                                          '',
                                      style: DMSansFont.textStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Color(0xFFE0E0E0),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Color(0xFF757575),
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: Icon(Icons.close_rounded, size: 24),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required Color titleColor,
    required List<String> items,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: DMSansFont.textStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: DMSansFont.textStyle(
                        fontSize: 13,
                        color: Color(0xFF424242),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatDateTime(DateTime dateTime, String locale) {
    final dateFormat = DateFormat.yMMMMd(locale); // e.g., ١٩ يونيو، ٢٠٢٥
    final timeFormat = DateFormat.jm(locale); // e.g., ٢:٣٠ م or 2:30 PM
    return '${dateFormat.format(dateTime)}, ${timeFormat.format(dateTime)}';
  }

  /// Checks if the warranty status hasn't been updated for more than 2 days
  /// OR if the original technician has rejected the warranty request
  bool _shouldShowComplaintButton() {
    final warranty = booking.warranty;
    if (warranty == null) return false;

    // Only show for specific warranty statuses (Requested or Accepted)
    if (warranty.warrantyStatusCode != 'R' &&
        warranty.warrantyStatusCode != 'S') {
      return false;
    }

    // Check if the original technician has rejected the warranty request
    final originalTechnicianId = booking.agent?.uid;
    if (originalTechnicianId != null &&
        warranty.rejectedTechnicians != null &&
        warranty.rejectedTechnicians!.isNotEmpty) {
      final hasOriginalTechRejected = warranty.rejectedTechnicians!.any(
        (rejectedTech) => rejectedTech.uid == originalTechnicianId,
      );
      if (hasOriginalTechRejected) {
        return true; // Show button immediately if original tech rejected
      }
    }

    // Check if updatedAt exists for time-based condition
    if (warranty.updatedAt == null) return false;

    // Calculate the difference in days
    final daysSinceUpdate = DateTime.now()
        .difference(warranty.updatedAt!)
        .inDays;

    // Show button if more than 2 days have passed
    return daysSinceUpdate > 2;
  }

  int calculateDaysLeft() {
    final endDate = booking.warranty?.createdAt!.add(Duration(days: 7));
    final daysLeft = endDate!.difference(DateTime.now()).inDays;
    return daysLeft;
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlighted = false,
    bool needCopy = false,
    required Icon? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: needCopy
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.center,
        children: [
          // SizedBox(
          //   width: 100,
          //   child: Text(
          //     label,
          //     style: DMSansFont.textStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.w500,
          //       color: Colors.grey[600],
          //     ),
          //   ),
          // ),
          Expanded(child: Icon(icon!.icon)),
          const SizedBox(width: 5),
          Expanded(
            flex: 9,
            child: Text(
              value,
              style: DMSansFont.textStyle(
                fontSize: 10,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: Color(0xff3C3C43),
              ),
            ),
          ),
          if (needCopy) ...{
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: booking.id));
                },
                icon: Icon(Icons.copy),
                iconSize: 16,
                style: ButtonStyle(
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}
