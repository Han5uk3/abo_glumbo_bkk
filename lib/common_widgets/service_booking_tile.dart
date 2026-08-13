import 'package:abo_glumbo_bbk/services/time_service.dart';
import 'dart:developer';

import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/date_formatter.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/booking_bloc.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/sheets/payment.dart';

import 'package:abo_glumbo_bbk/pages/bookings/booking_details_page.dart';
import 'package:abo_glumbo_bbk/sheets/cancel_booking_dialog.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                            Text(
                              "#${booking.newBookingId ?? booking.id}",
                              style: TextStyle(fontSize: 9),
                            ),
                            const SizedBox(height: 4),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.black,
                              ),
                            ),

                            // Text(
                            //   booking.service.descriptionLocalized(
                            //         languageCode:
                            //             AppLocalizations.of(context)?.localeName ??
                            //             'en',
                            //       ) ??
                            //       '',
                            //   style: TextStyle(
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
                          if (booking.bookingStatusCode == "C" ||
                              booking.bookingStatusCode == "VP")
                            Text(
                              "${((booking.completionData?.totalCost ?? 0) + booking.service.getDiscountedPrice(booking.effectiveInspectionFee)).toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}",
                              style: TextStyle(
                                color: AppColors.green1,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          if (booking.isOnHour != null)
                            Padding(
                              padding: EdgeInsets.only(
                                top:
                                    (booking.bookingStatusCode == "C" ||
                                        booking.bookingStatusCode == "VP")
                                    ? 4.0
                                    : 0.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: booking.isOnHour == true
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  booking.isOnHour == true
                                      ? AppLocalizations.of(context)!.onHour
                                      : AppLocalizations.of(context)!.offHour,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: booking.isOnHour == true
                                        ? Colors.blue
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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


            // Wrap(
            //   alignment: WrapAlignment.start,
            //   children: [
            if (customerSelectedAddress != null)
              _buildInfoRow(
                localization.location,
                "${customerSelectedAddress.buildingNumber.isNotEmpty ? '${customerSelectedAddress.buildingNumber}, ' : ''}${customerSelectedAddress.streetName ?? 'N/A'}",
                icon: const Icon(Icons.location_on_outlined),
              ),

            if (isWarranty && _shouldShowComplaintButton())
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
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
                                  style: TextStyle(
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
                            style: TextStyle(fontSize: 14, height: 1.5),
                          ),
                          actions: [
                            eButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              context: context,
                              backgroundColor: Colors.white,
                              text: AppLocalizations.of(context)!.cancel,
                              textColor: Colors.black,
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
                                style: TextStyle(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.bgWhite,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (isWarranty && booking.isEscalated == true)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.escalated,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              )
            else if (isWarranty &&
                booking.resolvedAt != null &&
                booking.resolutionText != null &&
                booking.resolutionText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)?.resolved ??
                                'Resolved',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        booking.resolutionText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
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
                          style: TextStyle(
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
                        style: TextStyle(
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
                        style: TextStyle(
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
                        style: TextStyle(
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

    final dateToUse = booking.assignedAt ?? booking.acceptedAt;
    if (dateToUse != null && booking.bookingStatusCode == "A") {
      return _timestampText(
        "${AppLocalizations.of(context)!.acceptedOn} : ${formatBookingDateTime(dateToUse.toDate(), locale)}",
      );
    }

    if (booking.completedAt != null && booking.bookingStatusCode == "C") {
      return _timestampText(
        "${AppLocalizations.of(context)!.completedOn} : ${formatBookingDateTime(booking.completedAt!.toDate(), locale)}",
      );
    }

    if (booking.bookingStatusCode == "VP") {
      if (booking.paidAt != null) {
        return _timestampText(
          "${AppLocalizations.of(context)!.paidOn} : ${formatBookingDateTime(booking.paidAt!.toDate(), locale)}",
        );
      } else if (booking.completedAt != null) {
        return _timestampText(
          "${AppLocalizations.of(context)!.completedOn} : ${formatBookingDateTime(booking.completedAt!.toDate(), locale)}",
        );
      }
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
      "E": (warranty.expiredOn != null && warranty.availability == false)
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
        if ((booking.bookingStatusCode == "C" ||
                booking.bookingStatusCode == "CP") &&
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
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 8,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildPaymentButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        showPaymentBottomSheet(
          context,
          agent: booking.agent ?? UserModel(role: 'technician'),
          service: booking.service,
          customerData: booking.customer,
          booking: booking,
        );
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
            AppLocalizations.of(context)!.completePayment.toUpperCase(),
            style: TextStyle(
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
          style: TextStyle(
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
      case "X":
        if (statusCode == "X") {
          return _buildWarrantyBadge(
            label: AppLocalizations.of(context)?.rejected ?? '',
            color: Colors.red,
            textColor: Colors.red,
            borderOnly: true,
          );
        }
        return _buildWarrantyBadge(
          label: AppLocalizations.of(context)?.repairUnderWarranty ?? '',
          color: AppColors.primary,
          textColor: Colors.white,
          onTap: () => showWarrantyClaimedBottomSheet(context, booking),
        );
      case "E":
        if (warranty.availability == false) {
          return _buildWarrantyBadge(
            label: AppLocalizations.of(context)?.expired ?? '',
            color: Colors.grey,
            textColor: Colors.grey,
            borderOnly: true,
          );
        }
        return SizedBox.shrink();
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
            style: TextStyle(
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
                                style: TextStyle(
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
                                style: TextStyle(
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
                            style: TextStyle(
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
                  child: _WarrantyClaimForm(
                    booking: booking,
                    isExpiringSoon: isExpiringSoon,
                    onRefresh: onRefresh,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders in Saudi time; [instant] is an absolute instant. See [KsaTime].
  String formatDateTime(DateTime instant, String locale) {
    final dateTime = KsaTime.fromInstant(instant);
    final dateFormat = DateFormat.yMMMMd(locale); // e.g., ١٩ يونيو، ٢٠٢٥
    final timeFormat = DateFormat.jm(locale); // e.g., ٢:٣٠ م or 2:30 PM
    return '${dateFormat.format(dateTime)}, ${timeFormat.format(dateTime)}';
  }

  /// The complaint button is the customer's escape hatch when a warranty claim
  /// stalls. It appears for three separate reasons:
  ///
  ///  1. the admin rejected the claim outright (status X);
  ///  2. the assigned technician dropped it and nobody has picked it up since;
  ///  3. nothing at all has happened on the claim for 24 hours.
  ///
  /// (1) and (2) are concrete events, so they are answered by what the claim
  /// looks like now. (3) is silence, so it is measured against the clock.
  bool _shouldShowComplaintButton() {
    final warranty = booking.warranty;
    if (warranty == null) return false;

    // A finished claim has nothing left to chase.
    if (warranty.warrantyStatusCode == 'C') return false;

    // Still inside the warranty window? Compared as instants, not as whole
    // days: `calculateDaysLeft()` truncates with `inDays`, so it reports 0 -
    // "expired" - for the entire final day of a live warranty. On a 7-day
    // window that hid the button for the last 24 hours, which is exactly when a
    // claim raised late in the window needs it most.
    final now = TimeService.now;
    final endsAt =
        warranty.expiredOn ??
        warranty.createdAt?.add(const Duration(days: 7));
    if (endsAt == null || !now.isBefore(endsAt)) return false;

    // Already complained - the tile shows the "escalated" badge instead.
    if (booking.isEscalated == true) return false;

    // When the admin resolves a complaint, the events that caused it are still
    // written on the claim (the rejection, the empty assignment). Without this,
    // reasons (1) and (2) would re-arm the button the instant the complaint was
    // resolved and the customer would keep re-reporting the same thing. So a
    // failure only counts if it happened after the last resolution.
    final resolvedAt = booking.resolvedAt?.toDate();
    bool isUnaddressed(DateTime? failedAt) {
      if (resolvedAt == null) return true;
      return failedAt != null && failedAt.isAfter(resolvedAt);
    }

    // 1. Admin rejected the claim.
    if (warranty.warrantyStatusCode == 'X') {
      return isUnaddressed(warranty.rejectedAt);
    }

    // 2. The claim lost its technician and is waiting to be reassigned. Both
    // fields matter: a cancellation clears the id and the embedded technician
    // together, and either one left behind means somebody is still on it.
    final isUnassigned =
        (warranty.assignedTechnician == null ||
            warranty.assignedTechnician!.isEmpty) &&
        (warranty.assignedTechnicianId == null ||
            warranty.assignedTechnicianId!.isEmpty);

    DateTime? lastRejectionAt = warranty.rejectedAt;
    for (final rejection in warranty.rejectedTechnicians ?? const []) {
      final rejectedAt = rejection.rejectedAt;
      if (rejectedAt == null) continue;
      if (lastRejectionAt == null || rejectedAt.isAfter(lastRejectionAt)) {
        lastRejectionAt = rejectedAt;
      }
    }
    final hasRejections =
        (warranty.rejectedTechnicians?.isNotEmpty ?? false) ||
        warranty.rejectedAt != null;

    if (hasRejections && isUnassigned) {
      return isUnaddressed(lastRejectionAt);
    }

    // 3. Silence. Every real action on a claim - requesting it, assigning,
    // accepting, cancelling, completing - stamps `warranty.updatedAt`, so this
    // measures genuine inactivity.
    final lastActivity =
        warranty.updatedAt ?? warranty.requestedOn ?? warranty.createdAt;
    if (lastActivity == null) return false;

    // Resolving a complaint restarts the clock, which is what gives the admin
    // their day to actually fix things before the customer can complain again.
    var silentSince = lastActivity;
    if (resolvedAt != null && resolvedAt.isAfter(silentSince)) {
      silentSince = resolvedAt;
    }

    // 24 hours, measured as a duration. The previous test was
    // `difference(...).inDays > 1`, and because `inDays` truncates that only
    // became true at the 48-hour mark - a full day later than intended.
    return now.difference(silentSince) >= const Duration(hours: 24);
  }

  int calculateDaysLeft() {
    final endDate =
        booking.warranty?.expiredOn ??
        booking.warranty?.createdAt?.add(const Duration(days: 7));
    if (endDate == null) return 0;
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    return daysLeft < 0 ? 0 : daysLeft;
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
          //     style: TextStyle(
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
              style: TextStyle(
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

/// Shared section card builder used by both [ServiceBookingTile] and [_WarrantyClaimForm].
Widget _buildSectionCardWidget({
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF424242),
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

/// Shared section card builder (alias for use in [_WarrantyClaimForm]).
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
  return _buildSectionCardWidget(
    context: context,
    icon: icon,
    iconColor: iconColor,
    iconBgColor: iconBgColor,
    title: title,
    titleColor: titleColor,
    items: items,
    gradientColors: gradientColors,
  );
}

/// Stateful form widget for warranty claim with date/time picker.
class _WarrantyClaimForm extends StatefulWidget {
  final BookingModel booking;
  final bool isExpiringSoon;
  final VoidCallback onRefresh;

  const _WarrantyClaimForm({
    required this.booking,
    required this.isExpiringSoon,
    required this.onRefresh,
  });

  @override
  State<_WarrantyClaimForm> createState() => _WarrantyClaimFormState();
}

class _WarrantyClaimFormState extends State<_WarrantyClaimForm> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submitClaim() async {
    final localizations = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);

    try {
      final updateData = <String, dynamic>{
        'warranty.warrantyStatusCode': 'R',
        'warranty.availability': false,
        'warranty.acceptedAt': Timestamp.now(),
        'warranty.updatedAt': Timestamp.now(),
        'warranty.claimrequested': true,
        'warranty.requestedOn': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      final techId =
          widget.booking.agent?.uid ??
          widget.booking.warranty?.assignedTechnicianId;

      if (techId != null && techId.isNotEmpty) {
        updateData['warranty.assignedTechnicianId'] = techId;

        final techDoc = await AppFirestore.usersCollectionRef.doc(techId).get();
        if (techDoc.exists) {
          updateData['warranty.assignedTechnician'] = techDoc.data();
        } else if (widget.booking.warranty?.assignedTechnician != null) {
          updateData['warranty.assignedTechnician'] =
              widget.booking.warranty!.assignedTechnician;
        } else if (widget.booking.agent != null) {
          updateData['warranty.assignedTechnician'] = widget.booking.agent!
              .toJson();
        }
      }

      await AppFirestore.bookingsCollectionRef
          .doc(widget.booking.id)
          .update(updateData);

      if (!mounted) return;

      showSnackBar(
        localizations.repairRequestedSuccessfully,
        context,
        backgroundColor: Colors.green,
      );

      navigator.pop();
      widget.onRefresh.call();
    } catch (e) {
      log(e.toString());
      if (!mounted) return;

      showSnackBar(
        "${localizations.error} : $e",
        context,
        backgroundColor: Colors.red,
      );
      navigator.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // What's Covered Section
        _buildSectionCard(
          context: context,
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF4CAF50),
          iconBgColor: const Color(0xFF4CAF50).withOpacity(0.1),
          title: localization.whatsCovered,
          titleColor: const Color(0xFF2E7D32),
          items: [
            localization.issueone,
            localization.issuetwo,
            localization.issuethree,
            localization.issuefour,
          ],
          gradientColors: [
            const Color(0xFF4CAF50).withOpacity(0.05),
            const Color(0xFF81C784).withOpacity(0.05),
          ],
        ),
        const SizedBox(height: 16),

        // What's NOT Covered Section
        _buildSectionCard(
          context: context,
          icon: Icons.cancel_rounded,
          iconColor: const Color(0xFFE53935),
          iconBgColor: const Color(0xFFE53935).withOpacity(0.1),
          title: localization.whatsNotCovered,
          titleColor: const Color(0xFFC62828),
          items: [
            localization.notissueone,
            localization.notissuetwo,
            localization.notissuethree,
            localization.notissuefour,
            localization.notissuefive,
          ],
          gradientColors: [
            const Color(0xFFE53935).withOpacity(0.05),
            const Color(0xFFEF5350).withOpacity(0.05),
          ],
        ),
        const SizedBox(height: 16),

        // Important Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  size: 24,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.importantInformation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      localization.claimText,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF424242),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSubmitting
                        ? [Colors.grey, Colors.grey.shade400]
                        : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (!_isSubmitting)
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.build_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              localization.requestRepair,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF757575),
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Icon(Icons.close_rounded, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
