// ignore_for_file: deprecated_member_use

import 'package:abo_glumbo_bbk/common_widgets/cached_video_player.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/sheets/payment.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/date_formatter.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/warranty.dart';
import 'package:abo_glumbo_bbk/pages/bookings/timeline.dart';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/services/chat_services.dart';
import 'package:abo_glumbo_bbk/services/time_service.dart';
import 'package:abo_glumbo_bbk/services/booking/invoice_service.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/utils/whatsapp_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/pages/bookings/rebook_service_selection.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class BookingDetailsPage extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onRefresh;
  final bool isWarranty;

  const BookingDetailsPage({
    super.key,
    required this.booking,
    this.onRefresh,
    this.isWarranty = false,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  // Convenience accessors — lets all class methods use 'booking' & 'isWarranty'
  // without requiring every call site to be updated to widget.xxx.
  BookingModel get booking => widget.booking;
  bool get isWarranty => widget.isWarranty;
  VoidCallback? get onRefresh => widget.onRefresh;

  Widget _buildTimestampText(BuildContext context, BookingModel booking) {
    if (widget.isWarranty) {
      return _buildWarrantyTimestamp(context, booking);
    }
    return _buildBookingTimestamp(context, booking);
  }

  Widget _buildBookingTimestamp(BuildContext context, BookingModel booking) {
    final locale = AppLocalizations.of(context)?.localeName ?? 'en';

    if ((booking.bookingStatusCode == "P" ||
            booking.bookingStatusCode == "SR") &&
        booking.createdAt != null) {
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

  Widget _buildWarrantyTimestamp(BuildContext context, BookingModel booking) {
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
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: AppColors.black1, fontSize: 10.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: AppFirestore.bookingsCollectionRef
          .doc(widget.booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        final docData = snapshot.data?.data() as Map<String, dynamic>?;
        final booking = docData != null
            ? BookingModel.fromMap(docData)
            : widget.booking;

        _checkRebookTimeout(booking);

        final textTheme = Theme.of(context).textTheme;
        final colorScheme = Theme.of(context).colorScheme;
        final localization = AppLocalizations.of(context)!;

        AddressModel? customerSelectedAddress =
            booking.customer.addresses.isEmpty
            ? null
            : booking.customer.addresses.firstWhere(
                (address) => address.isSelected ?? false,
                orElse: () => booking.customer.addresses.first,
              );

        final List<Widget> tabs = [];
        final List<Widget> tabViews = [];

        // Tab 1: SERVICE (Always shown)
        tabs.add(Tab(text: localization.service));
        tabViews.add(
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServiceInfoRow(
                  booking.service.nameLocalized(
                        languageCode: localization.localeName,
                      ) ??
                      "",
                  booking.service.descriptionLocalized(
                        languageCode: localization.localeName,
                      ) ??
                      "",
                  context,
                ),

                _buildLocationCard(customerSelectedAddress, context),
                SizedBox(height: 12),

                if (!isWarranty)
                  _buildSectionCard(
                    context: context,
                    hasChat: false,
                    title: localization.schedule,
                    icon: Icons.schedule_rounded,
                    children: [
                      _buildInfoRow(
                        localization.dateAndTime,
                        formatDateTime(
                          booking.bookingDateTime.toDate(),
                          AppLocalizations.of(context)?.localeName ?? '',
                        ),
                      ),
                    ],
                  ),
                if (!isWarranty) ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context: context,
                    hasChat: false,
                    title: localization.pricingAndPayment,
                    icon: Icons.payments_rounded,
                    children: [
                      if (booking.isOnHour != null)
                        _buildInfoRow(
                          booking.isOnHour == true
                              ? localization.onHour
                              : localization.offHour,
                          "",
                        ),
                      _buildInfoRow(
                        localization.inspectionFee,
                        '${booking.service.getDiscountedPrice(booking.effectiveInspectionFee).toStringAsFixed(2)} ${localization.sar}',
                      ),
                    ],
                  ),
                ],
                if ((booking.issueImage != null &&
                        booking.issueImage!.isNotEmpty) ||
                    (booking.issueVideo != null &&
                        booking.issueVideo!.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  _buildIssueMediaCard(context, textTheme, colorScheme),
                ],
                if (booking.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context: context,
                    hasChat: false,
                    title: localization.additionalNotes,
                    icon: Icons.note_outlined,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          booking.notes,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (booking.bookingStatusCode == 'X' ||
                    booking.bookingStatusCode == 'XC' ||
                    booking.bookingStatusCode == 'R') ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context: context,
                    hasChat: false,
                    title: localization.cancellationDetails,
                    icon: Icons.cancel_rounded,
                    children: [
                      if (booking.bookingStatusCode == 'XC') ...[
                        _buildInfoRow(
                          localization.cancelledBy,
                          localization.customer,
                        ),
                        if (booking.cancelledAt != null)
                          _buildInfoRow(
                            localization.cancelledOn,
                            formatDateTime(
                              booking.cancelledAt!.toDate(),
                              AppLocalizations.of(context)?.localeName ?? '',
                            ),
                          ),
                      ],
                      if (booking.bookingStatusCode == 'X') ...[
                        _buildInfoRow(
                          localization.cancelledBy,
                          localization.serviceProvider,
                        ),
                        if (booking.cancelledAt != null)
                          _buildInfoRow(
                            localization.cancelledOn,
                            formatDateTime(
                              booking.cancelledAt!.toDate(),
                              AppLocalizations.of(context)?.localeName ?? '',
                            ),
                          ),
                      ],
                      if (booking.bookingStatusCode == 'R') ...[
                        _buildInfoRow(
                          localization.rejectedBy,
                          localization.admin,
                        ),
                        if (booking.rejectedAt != null)
                          _buildInfoRow(
                            localization.rejectedOn,
                            formatDateTime(
                              booking.rejectedAt!.toDate(),
                              AppLocalizations.of(context)?.localeName ?? '',
                            ),
                          ),
                      ],
                      if (booking.cancellationReason != null &&
                          (booking.cancellationReason ?? "").isNotEmpty)
                        _buildInfoRow(
                          localization.cancellationReason,
                          booking.cancellationReason ?? "",
                        ),
                    ],
                  ),
                ],
                if (isWarranty && booking.warranty != null) ...[
                  const SizedBox(height: 16),
                  _buildWarrantyDataCard(context),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        );

        // Tab 2: TECHNICIAN (Conditional)
        final bool isActiveWarranty =
            isWarranty &&
            booking.warranty != null &&
            ['R', 'A', 'S'].contains(booking.warranty!.warrantyStatusCode);
        final UserModel? activeAgent =
            isActiveWarranty && booking.warranty!.assignedTechnician != null
            ? UserModel.fromJson(booking.warranty!.assignedTechnician!)
            : booking.agent;

        if (activeAgent != null && (activeAgent.uid ?? "").isNotEmpty) {
          tabs.add(Tab(text: localization.technician));
          tabViews.add(
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    context: context,
                    hasChat: true,
                    showChatOnHeader: false,
                    title: localization.technician,
                    icon: Icons.person_outline,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          CachedNetworkImage(
                            imageUrl: activeAgent.profileUrl ?? "",
                            imageBuilder: (context, imageProvider) =>
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: imageProvider,
                                ),
                            placeholder: (context, url) => CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.blue1.withOpacity(0.1),
                              child: Text(
                                _getInitials(activeAgent.name ?? ""),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.blue1.withOpacity(0.1),
                              child: Text(
                                _getInitials(activeAgent.name ?? ""),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activeAgent.name ?? "",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (booking.bookingStatusCode == 'A' ||
                              (isActiveWarranty &&
                                  booking.warranty?.warrantyStatusCode == 'S'))
                            GestureDetector(
                              onTap: () =>
                                  _openOrCreateChat(context, activeAgent),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/icons/chat2.png',
                                  width: 16,
                                  height: 16,
                                ),
                              ),
                            ),
                          if (activeAgent.phone != null &&
                              (booking.bookingStatusCode == 'A' ||
                                  (isActiveWarranty &&
                                      booking.warranty?.warrantyStatusCode ==
                                          'S')))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => WhatsAppUtils.launchWhatsApp(
                                  activeAgent.phone!,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    'assets/images/whatsapp.png',
                                    width: 30,
                                    height: 30,
                                  ),
                                ),
                              ),
                            ),
                          if (booking.bookingStatusCode != 'C' ||
                              (isActiveWarranty &&
                                  booking.warranty?.warrantyStatusCode != 'E' &&
                                  booking.warranty?.warrantyStatusCode != 'C'))
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: GestureDetector(
                                onTap: () {
                                  final phone = (activeAgent.phone ?? "")
                                      .replaceAll(RegExp(r'[^\d+]'), '');
                                  _launchUrl('tel:$phone');
                                },
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.call_rounded,
                                    color: AppColors.green,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (booking.bookingStatusCode == 'C' && !isActiveWarranty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RebookServiceSelection(
                                          technician: activeAgent,
                                        ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                localization.rebookTechnician,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // Tab 3: COMPLETION (Conditional)
        final bool hasCompletionData =
            booking.completionData != null ||
            (booking.paymentProof != null && booking.paymentProof!.isNotEmpty);
        final bool showCompletionDetails =
            booking.bookingStatusCode == 'C' ||
            booking.bookingStatusCode == 'CP' ||
            booking.bookingStatusCode == 'VP' ||
            booking.bookingStatusCode.toLowerCase() == 'completed';

        if (showCompletionDetails || hasCompletionData) {
          tabs.add(Tab(text: localization.completionDetails));
          tabViews.add(
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCompletionDetails) ...[
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.pricingAndPayment,
                      icon: Icons.payments_rounded,
                      children: [
                        _buildInfoRow(
                          localization.mode,
                          (booking.completionData == null ||
                                  booking.completionData?.mode == 0)
                              ? localization.inspectionOnly
                              : localization.fullService,
                        ),
                        if (booking.completionData?.totalCost != null)
                          _buildInfoRow(
                            localization.amount,
                            '${((booking.completionData?.totalCost ?? 0.0) + booking.service.getDiscountedPrice(booking.effectiveInspectionFee)).toStringAsFixed(2)} ${localization.sar}',
                            isHighlighted: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCompletionDataCard(context),
                  ],
                ],
              ),
            ),
          );
        }

        final bool hasTip = booking.review?.isTipPaid == true && booking.review?.tipAmount != null && booking.review!.tipAmount! > 0;
        final bool hasActualReview = booking.review != null && (booking.review!.rating != null || booking.review!.review.isNotEmpty);

        // Tab 4: REVIEW (Conditional)
        if (hasActualReview || hasTip) {
          tabs.add(Tab(text: localization.review));
          tabViews.add(
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasActualReview)
                    Container(
                      width: double.maxFinite,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.blue1.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.star_outline,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.review,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.grey.shade300, thickness: 1),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (booking.review!.rating != null) // Avoid null error if rating is null
                                    Row(
                                      children: [
                                        Text(
                                          booking.review!.rating!.toStringAsFixed(
                                            1,
                                          ),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Row(
                                          children: List.generate(5, (index) {
                                            final rating =
                                                (booking.review!.rating ?? 0.0)
                                                    .toDouble();
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 2,
                                              ),
                                              child: Icon(
                                                index < rating.floor()
                                                    ? Icons.star
                                                    : index < rating
                                                    ? Icons.star_half
                                                    : Icons.star_border,
                                                color: const Color(0xFFFBBF24),
                                                size: 16,
                                              ),
                                            );
                                          }),
                                        ),
                                        Spacer(),
                                        if (booking.review!.createdAt != null)
                                        Text(
                                          _formatTimeAgo(
                                            booking.review!.createdAt!.toDate(),
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (booking.review!.rating != null)
                                      Divider(
                                        color: Colors.grey.shade300,
                                        thickness: 1,
                                      ),
                                    Text(
                                      booking.review!.review,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (hasActualReview && hasTip)
                    const SizedBox(height: 16),
                  if (hasTip)
                    Container(
                      width: double.maxFinite,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.volunteer_activism_outlined,
                                  size: 16,
                                  color: AppColors.green,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.tipAmount,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.grey.shade300, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.tip,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '${booking.review!.tipAmount!.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // Tab 5: TIMELINE (Always shown)
        tabs.add(Tab(text: localization.bookingTimeline));
        tabViews.add(
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildBookingTimelineCard(
                  context,
                  textTheme,
                  colorScheme,
                  isWarranty,
                  booking,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: AppColors.bgBlueTint,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    centerTitle: true,
                    pinned: true,
                    floating: true,
                    leading: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      localization.bookingDetails,
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          width: double.maxFinite,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xffEAF1FF).withOpacity(0.50),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text(
                                                "${AppLocalizations.of(context)!.bookingId}: ",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                booking.newBookingId ??
                                                    booking.id,
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text:
                                                    booking.newBookingId ??
                                                    booking.id,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.bookingIdCopied,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: Icon(
                                            Icons.copy,
                                            size: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                  ],
                                ),
                              ),
                              const Divider(
                                thickness: 0.5,
                                color: Colors.black,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildTimestampText(context, booking),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        isScrollable: true,
                        tabAlignment:
                            Directionality.of(context) == TextDirection.rtl
                            ? TabAlignment.center
                            : TabAlignment.start,
                        labelColor: AppColors.blue1,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.blue1,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tabs: tabs,
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: tabViews,
              ),
            ),
            bottomNavigationBar: _buildBottomAction(context, booking),
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(
    AddressModel? customerSelectedAddress,
    BuildContext context,
  ) {
    final localization = AppLocalizations.of(context)!;
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.blue1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Text(
                localization.location,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Divider(thickness: 1, color: Colors.grey.shade300),
          Text(
            customerSelectedAddress == null
                ? ""
                : "${customerSelectedAddress.buildingNumber.isNotEmpty ? '${customerSelectedAddress.buildingNumber}, ' : ''}${customerSelectedAddress.streetName ?? ""}",
            style: TextStyle(fontSize: 12, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrCreateChat(
    BuildContext context,
    UserModel activeAgent,
  ) async {
    final chatService = ChatService();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgBlueTint,
          content: SizedBox(
            height: 70,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 24, child: Loader(color: AppColors.primary)),
                  Text(AppLocalizations.of(context)!.loadingChat),
                ],
              ),
            ),
          ),
        ),
      );

      String chatId;
      if (booking.chatroomId.isNotEmpty) {
        chatId = booking.chatroomId;
      } else {
        if (chatService.currentUserId.isEmpty) {
          throw Exception('User not authenticated');
        }

        chatId = await chatService.createChat(
          booking.id,
          activeAgent.uid ?? '',
          activeAgent.name ?? 'Technician',
          activeAgent.profileUrl ?? '',
          booking.customer.name ?? 'Customer',
          '',
          'customer',
        );

        await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
          'chatroomId': chatId,
        });
      }

      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              participantName: activeAgent.name ?? 'Technician',
              participantId: activeAgent.uid ?? '',
              participantPhoto: activeAgent.profileUrl ?? '',
              customerName: widget.booking.customer.name ?? 'Customer',
              customerPhoto: '',
              bookingId: widget.booking.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.failedToOpenChat(e.toString()) ??
                  'Failed to open chat: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWarrantyDataCard(BuildContext context) {
    return _buildSectionCard(
      context: context,
      hasChat: false,
      title: AppLocalizations.of(context)!.warrantyDetails,
      icon: Icons.verified_user,
      children: [
        _buildInfoRow(
          AppLocalizations.of(context)!.status,
          getWarrantyStatus(booking.warranty!.warrantyStatusCode, context),
        ),
        _buildInfoRow(
          AppLocalizations.of(context)!.appliedOn,
          formatDateTime(
            booking.warranty!.createdAt!,
            AppLocalizations.of(context)?.localeName ?? '',
          ),
        ),

        if (booking.warranty!.warrantyStatusCode != 'E')
          _buildInfoRow(
            AppLocalizations.of(context)!.expiresOn,
            formatDateTime(
              getExpiryDate(booking.warranty!),
              AppLocalizations.of(context)?.localeName ?? '',
            ),
          ),
        if (booking.warranty!.warrantyStatusCode == 'S' &&
            booking.warranty!.acceptedAt != null) ...[
          _buildInfoRow(
            AppLocalizations.of(context)!.acceptedOn,
            formatDateTime(
              booking.warranty!.acceptedAt!,
              AppLocalizations.of(context)?.localeName ?? '',
            ),
          ),
        ],

        if (booking.warranty!.warrantyStatusCode == 'E' &&
            booking.warranty!.requestedOn != null) ...[
          _buildInfoRow(
            AppLocalizations.of(context)!.expiredOn,
            formatDateTime(
              booking.warranty!.expiredOn!,
              AppLocalizations.of(context)?.localeName ?? '',
            ),
          ),
        ],

        if (booking.warranty!.warrantyStatusCode == 'R' &&
            booking.warranty!.requestedOn != null) ...[
          _buildInfoRow(
            AppLocalizations.of(context)!.requestedOn,
            formatDateTime(
              booking.warranty!.requestedOn!,
              AppLocalizations.of(context)?.localeName ?? '',
            ),
          ),
        ],
        if (booking.warranty!.warrantyStatusCode == 'C' &&
            booking.warranty!.completedAt != null) ...[
          _buildInfoRow(
            AppLocalizations.of(context)!.completedOn,
            formatDateTime(
              booking.warranty!.completedAt!,
              AppLocalizations.of(context)?.localeName ?? '',
            ),
          ),
        ],
      ],
    );
  }

  String getWarrantyStatus(String status, BuildContext context) {
    final s = status.toLowerCase();

    // Check for client-side expiration only for Active or Rejected status
    if (s == 'a' || s == 'x') {
      final warranty = booking.warranty;
      if (warranty != null && warranty.createdAt != null) {
        final expiryDate =
            warranty.expiredOn ??
            warranty.createdAt!.add(const Duration(days: 7));
        if (DateTime.now().isAfter(expiryDate)) {
          return AppLocalizations.of(context)!.expired;
        }
      }
    }

    switch (s) {
      case 'a':
        return AppLocalizations.of(context)!.active;
      case 'r':
        return AppLocalizations.of(context)!.requested;
      case 's':
        return AppLocalizations.of(context)!.accepted;
      case 'c':
        return AppLocalizations.of(context)!.claimed;
      case 'e':
        return AppLocalizations.of(context)!.expired;
      case 'x':
        return AppLocalizations.of(context)!.rejected;
      default:
        return AppLocalizations.of(context)!.unknown;
    }
  }

  DateTime getExpiryDate(WarrantyModel warranty) {
    return warranty.expiredOn ??
        warranty.createdAt!.add(const Duration(days: 7));
  }

  Widget _buildCompletionDataCard(BuildContext context) {
    final completionData =
        booking.completionData ??
        CompletionDataModel(
          fileUrls: [],
          mode: 0,
          paymentMethod: booking.paymentModeCode,
          serviceCost: 0,
          totalCost: 0,
          serviceItems: [],
          inspectionFee: booking.effectiveInspectionFee,
        );

    return _buildSectionCard(
      context: context,
      hasChat: false,
      title: AppLocalizations.of(context)!.completionDetails,
      icon: Icons.check_circle,
      children: [
        if (booking.bookingStatusCode == 'C' || isWarranty) ...[
          Text(
            AppLocalizations.of(context)!.invoiceWord,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (booking.paymentCompleted ||
              booking.bookingStatusCode == 'VP' ||
              (booking.bookingStatusCode == 'C' &&
                  !booking.paymentCompleted)) ...[
            if (booking.paymentCompleted && booking.orderId?.isNotEmpty == true)
              _buildInfoRow(
                AppLocalizations.of(context)!.transactionId,
                booking.orderId ?? "",
              ),

            _buildInfoRow(
              AppLocalizations.of(context)!.invoiceType,
              completionData.mode == 0
                  ? AppLocalizations.of(context)!.inspection
                  : AppLocalizations.of(context)!.fullService,
            ),
            if (booking.paymentCompleted || booking.paymentModeCode.isNotEmpty)
              _buildInfoRow(
                AppLocalizations.of(context)!.paymentMode,
                (booking.paymentModeCode.toLowerCase() == 'c' ||
                        booking.paymentModeCode.toLowerCase() == 'a')
                    ? AppLocalizations.of(context)!.insideApp
                    : AppLocalizations.of(context)!.outsideApp,
              ),
          ],

          GestureDetector(
            onTap: () async {
              bool loaderPopped = false;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const PopScope(
                  canPop: false,
                  child: Center(child: Loader(color: AppColors.primary)),
                ),
              );
              try {
                await InvoiceService.generateAndShowInvoice(
                  context,
                  booking,
                  onReady: () {
                    if (!loaderPopped && context.mounted) {
                      Navigator.pop(context);
                      loaderPopped = true;
                    }
                  },
                );
              } catch (e) {
                debugPrint('Error showing invoice: $e');
              } finally {
                if (!loaderPopped && context.mounted) {
                  Navigator.pop(context);
                  loaderPopped = true;
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 20,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.booking.newBookingId ?? "",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      bool loaderPopped = false;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const PopScope(
                          canPop: false,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                      try {
                        await InvoiceService.generateAndShareInvoice(
                          context,
                          booking,
                          onReady: () {
                            if (!loaderPopped && context.mounted) {
                              Navigator.pop(context);
                              loaderPopped = true;
                            }
                          },
                        );
                      } catch (e) {
                        debugPrint('Error sharing invoice: $e');
                      } finally {
                        if (!loaderPopped && context.mounted) {
                          Navigator.pop(context);
                          loaderPopped = true;
                        }
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.share_rounded, size: 18),
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (completionData.fileUrls.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context)!.uploadFilesTitle,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ..._buildFileLinks(context, completionData.fileUrls),
        ],

        if (completionData.serviceItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.serviceItems,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: completionData.serviceItems
                    .asMap()
                    .entries
                    .map(
                      (entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 12,
                                child: Text(
                                  entry.value.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'x${entry.value.quantity.toInt()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  '${entry.value.price.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (entry.key !=
                              completionData.serviceItems.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.costBreakdown,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),

        if (completionData.serviceCost > 0) ...[
          _buildInfoRow(
            AppLocalizations.of(context)!.serviceCost,
            '${completionData.serviceCost.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  AppLocalizations.of(context)!.inspectionFee,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    if (booking.service.discountPercentage != null &&
                        booking.service.discountPercentage! > 0)
                      Text(
                        '${booking.effectiveInspectionFee.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (booking.service.discountPercentage != null &&
                        booking.service.discountPercentage! > 0)
                      const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${booking.service.getDiscountedPrice(booking.effectiveInspectionFee).toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}${booking.service.discountPercentage != null && booking.service.discountPercentage! > 0 ? ' (${AppLocalizations.of(context)!.discountApplied(booking.service.discountPercentage!)})' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (booking.paymentProof != null &&
            booking.paymentProof!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.paymentProof,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ..._buildFileLinks(context, booking.paymentProof!),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.paymentCompleted
                    ? AppLocalizations.of(context)!.amountPaid
                    : AppLocalizations.of(context)!.amountToBePaid,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '${((completionData.totalCost) + booking.service.getDiscountedPrice(booking.effectiveInspectionFee)).toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  List<Widget> _buildFileLinks(BuildContext context, List<String> fileUrls) {
    return fileUrls
        .asMap()
        .entries
        .map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == fileUrls.length - 1 ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () => launchUrlString(entry.value),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(_getFileIcon(entry.value), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getFileName(entry.value),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new, size: 16),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  IconData _getFileIcon(String fileUrl) {
    String lowerUrl = fileUrl.toLowerCase();
    if (lowerUrl.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (lowerUrl.endsWith('.doc') || lowerUrl.endsWith('.docx')) {
      return Icons.description;
    } else if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png')) {
      return Icons.image;
    }
    return Icons.attachment;
  }

  String _getFileName(String fileUrl) {
    try {
      return "file ${int.tryParse((fileUrl.split('/').last.split('?').first.split("_").elementAt(3).substring(0, 1)))! + 1}${(fileUrl.split('/').last.split('?').first.split("_").elementAt(3).substring(1))}";
    } catch (e) {
      return "file";
    }
  }

  Widget _buildIssueMediaCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.blue1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.issueMedia,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            Divider(thickness: 1, color: Colors.grey.shade300),
            if (booking.issueImage != null && booking.issueImage!.isNotEmpty)
              const SizedBox(height: 20),

            const SizedBox(height: 8),
            if (booking.issueImage != null && booking.issueImage!.isNotEmpty)
              GestureDetector(
                onTap: () => _showFullScreenImage(booking.issueImage!, context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.image,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600]!,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Colors.grey[600]!,
                      ),
                    ],
                  ),
                ),
              ),
            if (booking.issueVideo != null && booking.issueVideo!.isNotEmpty)
              const SizedBox(height: 16),

            if (booking.issueVideo != null && booking.issueVideo!.isNotEmpty)
              GestureDetector(
                onTap: () => _showFullScreenVideo(booking.issueVideo!, context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.video,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600]!,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Colors.grey[600]!,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenVideo(String videoUrl, BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              AppLocalizations.of(context)!.issueVideo,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: CachedVideoPlayer(
              videoUrl: videoUrl,
              height: double.infinity,
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildStatusBadge(AppLocalizations localization) {
  //   Color statusColor;
  //   String statusText;
  //   IconData statusIcon;

  //   switch (booking.bookingStatusCode) {
  //     case 'P':
  //       statusColor = Colors.orange;
  //       statusText = localization.pending;
  //       statusIcon = Icons.schedule;
  //       break;
  //     case 'A':
  //       statusColor = Colors.blue;
  //       statusText = localization.accepted;
  //       statusIcon = Icons.check_circle;
  //       break;
  //     case 'R':
  //       statusColor = Colors.red;
  //       statusText = localization.rejected;
  //       statusIcon = Icons.cancel;
  //       break;
  //     case 'C':
  //       if (booking.paymentCompleted == true) {
  //         statusColor = Colors.green;
  //         statusText = localization.completed;
  //         statusIcon = Icons.check_circle;
  //       } else {
  //         statusColor = Colors.deepOrange;
  //         statusText = localization.paymentPending;
  //         statusIcon = Icons.wallet;
  //       }
  //       break;
  //     case 'X':
  //     case 'XC':
  //       statusColor = Colors.red;
  //       statusText = localization.cancelled;
  //       statusIcon = Icons.cancel;
  //       break;
  //     default:
  //       statusColor = Colors.grey;
  //       statusText = localization.unknown;
  //       statusIcon = Icons.help;
  //   }

  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: statusColor.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(color: statusColor.withOpacity(0.3)),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(statusIcon, color: statusColor, size: 16),
  //         const SizedBox(width: 6),
  //         Text(
  //           statusText,
  //           style: TextStyle(
  //             fontSize: 14,
  //             fontWeight: FontWeight.w600,
  //             color: statusColor,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool hasChat,
    bool showChatOnHeader = true,
    Widget? trailing,
  }) {
    final bool isActiveWarranty =
        isWarranty &&
        booking.warranty != null &&
        ['R', 'A', 'S'].contains(booking.warranty!.warrantyStatusCode);
    final UserModel? activeAgent =
        isActiveWarranty && booking.warranty!.assignedTechnician != null
        ? UserModel.fromJson(booking.warranty!.assignedTechnician!)
        : booking.agent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.blue1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing],
              if (showChatOnHeader &&
                  ((hasChat && booking.bookingStatusCode == 'A') ||
                      (hasChat &&
                          booking.warranty?.warrantyStatusCode == 'S' &&
                          isWarranty))) ...[
                const Spacer(),
                StreamBuilder<int>(
                  stream: booking.chatroomId.isNotEmpty
                      ? ChatService().getUnreadCountStream(booking.chatroomId)
                      : Stream.value(0),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return SizedBox(
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          if (activeAgent != null) {
                            _openOrCreateChat(context, activeAgent);
                          }
                        },
                        child: Stack(
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/icons/chat2.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 12,
                                top: 12,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (showChatOnHeader &&
                  activeAgent?.phone != null &&
                  ((hasChat && booking.bookingStatusCode == 'A') ||
                      (hasChat &&
                          booking.warranty?.warrantyStatusCode == 'S' &&
                          isWarranty))) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      WhatsAppUtils.launchWhatsApp(activeAgent!.phone!),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/whatsapp.png',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Divider(thickness: 1, color: Colors.grey.shade300),
          const SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  Widget _buildServiceInfoRow(
    String name,
    String description,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.blue1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.build_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)?.service ?? '',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Divider(thickness: 1, color: Colors.grey.shade300),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 45,
                    width: 45,
                    child: CachedNetworkImage(
                      imageUrl: booking.service.image ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Loader(color: AppColors.primary),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.image_outlined,
                        color: Colors.grey[400],
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                    SizedBox(height: 8),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          Divider(thickness: 0.5, color: Colors.grey.shade300),

          if (booking.service.price != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.inspectionFee}\t\t  ',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${booking.service.price} ${AppLocalizations.of(context)!.sar}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: isHighlighted ? AppColors.blue1 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatDateTime(DateTime dateTime, String locale) {
    return formatBookingDateTime(dateTime, locale);
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      bool canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        // Fallback: try direct launch as system schemes often work regardless of canLaunchUrl status
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showFullScreenImage(String imageUrl, BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              AppLocalizations.of(context)!.issueImage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 24,
                    child: Loader(size: 14, color: Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        size: 100,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.failedToLoadImage,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isCheckingTimeout = false;
  void _checkRebookTimeout(BookingModel booking) {
    if (_isCheckingTimeout) return;
    if (booking.rebookTechnicianId != null &&
        (booking.bookingStatusCode == 'P' ||
            booking.bookingStatusCode == 'SR')) {
      _isCheckingTimeout = true;
      AppFirestore.jobOffersCollectionRef
          .where('bookingId', isEqualTo: booking.id)
          .where('technicianId', isEqualTo: booking.rebookTechnicianId)
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final data = snapshot.docs.first.data() as Map<String, dynamic>;
              final status = data['status'] as String?;
              final expiresAt = data['expiresAt'] as Timestamp?;

              bool shouldFallback = false;

              if (status == 'declined') {
                shouldFallback = true;
              } else if (status == 'pending' &&
                  expiresAt != null &&
                  expiresAt.toDate().isBefore(TimeService.now)) {
                shouldFallback = true;
              }

              if (shouldFallback) {
                AppServices.fallbackToGeneralSearch(
                  booking.id,
                  booking.rebookTechnicianId,
                );
              }
            }
            _isCheckingTimeout = false;
          })
          .catchError((_) {
            _isCheckingTimeout = false;
          });
    }
  }

  Widget? _buildBottomAction(BuildContext context, BookingModel booking) {
    if (isWarranty) return null;

    final bool isPendingPayment =
        (booking.bookingStatusCode == 'C' ||
            booking.bookingStatusCode == 'CP') &&
        !booking.paymentCompleted;

    if (!isPendingPayment) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          showPaymentBottomSheet(
            context,
            agent: booking.agent ?? UserModel(role: 'technician'),
            service: booking.service,
            customerData: booking.customer,
            booking: booking,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.completePayment,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    String initials = "";
    if (parts.isNotEmpty) {
      initials += parts[0][0].toUpperCase();
    }
    if (parts.length > 1) {
      initials += parts[1][0].toUpperCase();
    }
    return initials;
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    final l10n = AppLocalizations.of(context)!;

    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return years == 1 ? l10n.yearAgo : l10n.yearsAgo(years);
    }
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? l10n.monthAgo : l10n.monthsAgo(months);
    }
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? l10n.weekAgo : l10n.weeksAgo(weeks);
    }
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? l10n.dayAgo : l10n.daysAgo(diff.inDays);
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? l10n.hourAgo : l10n.hoursAgo(diff.inHours);
    }
    if (diff.inMinutes >= 1) {
      return diff.inMinutes == 1
          ? l10n.minuteAgo
          : l10n.minutesAgo(diff.inMinutes);
    }
    return l10n.justNow;
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 for the divider
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1; // +1 for the divider

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
