// ignore_for_file: deprecated_member_use

import 'package:abo_glumbo_bbk/common_widgets/cached_video_player.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/services/chat_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<void> showBookingDetailsBottomSheet(
  BuildContext context, {
  required BookingModel booking,
  VoidCallback? onRefresh,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        BookingDetailsBottomSheet(booking: booking, onRefresh: onRefresh),
  );
}

class BookingDetailsBottomSheet extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onRefresh;

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final localization = AppLocalizations.of(context)!;

    AddressModel? customerSelectedAddress = booking.customer.addresses.isEmpty
        ? null
        : booking.customer.addresses.firstWhere(
            (address) => address.isSelected ?? false,
            orElse: () => booking.customer.addresses.first,
          );
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localization.bookingDetails,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBadge(localization),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    context: context,
                    hasChat: false,
                    title: localization.serviceInformation,
                    icon: Icons.build_rounded,
                    children: [
                      _buildInfoRow(
                        localization.service,
                        booking.service.nameLocalized(
                              languageCode:
                                  AppLocalizations.of(context)?.localeName ??
                                  '',
                            ) ??
                            'N/A',
                      ),
                      _buildInfoRow(
                        AppLocalizations.of(context)!.bookingId,
                        booking.id,
                        needCopy: true,
                      ),
                      // _buildInfoRow(
                      //     'Category', booking.service.category ?? 'N/A'),
                      if (booking.service.description?.isNotEmpty == true)
                        _buildInfoRow(
                          localization.description,
                          booking.service.descriptionLocalized(
                            languageCode:
                                AppLocalizations.of(context)?.localeName ?? '',
                          )!,
                        ),
                      if (booking.service.price != null)
                        _buildInfoRow(
                          localization.inspectionFee,
                          '${localization.sar} ${booking.service.price}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                  if ((booking.issueImage != null &&
                          booking.issueImage!.isNotEmpty) ||
                      (booking.issueVideo != null &&
                          booking.issueVideo!.isNotEmpty)) ...{
                    SizedBox(height: 16),
                    _buildIssueMediaCard(context, textTheme, colorScheme),
                    const SizedBox(height: 16),
                  },

                  if (booking.notes.isNotEmpty) ...{
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.additionalNotes,
                      icon: Icons.note_rounded,
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
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  },

                  if (customerSelectedAddress != null &&
                      customerSelectedAddress.buildingNumber.isNotEmpty)
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.location,
                      icon: Icons.location_on_rounded,
                      children: [
                        _buildInfoRow(
                          localization.address,
                          customerSelectedAddress.buildingNumber,
                        ),
                        _buildInfoRow(
                          localization.streetName,
                          customerSelectedAddress.streetName ?? 'N/A',
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (booking.agent != null)
                    _buildSectionCard(
                      context: context,
                      hasChat: true,
                      title: localization.technicianInfo,
                      icon: Icons.person_rounded,
                      children: [
                        if (booking.agent!.name?.isNotEmpty == true)
                          _buildInfoRow(
                            localization.name,
                            booking.agent!.name!,
                          ),

                        if (booking.agent!.phone?.isNotEmpty == true)
                          _buildClickableInfoRow(
                            localization.phoneNumber,
                            booking.agent!.phone!,
                            onTap: () =>
                                _launchUrl('tel:${booking.agent!.phone}'),
                            icon: Icons.phone,
                          ),
                        if (booking.agent!.email?.isNotEmpty == true)
                          _buildClickableInfoRow(
                            localization.emailAddress,
                            booking.agent!.email!,
                            onTap: () =>
                                _launchUrl('mailto:${booking.agent!.email}'),
                            icon: Icons.email,
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  if (booking.bookingStatusCode == 'C')
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.pricingAndPayment,
                      icon: Icons.payments_rounded,
                      children: [
                        _buildInfoRow(
                          localization.mode,
                          booking.completionData?.mode == 0
                              ? localization.inspectionOnly
                              : localization.fullService,
                        ),
                        if (booking.completionData?.totalCost != null)
                          _buildInfoRow(
                            localization.amount,
                            '${localization.sar} ${booking.completionData?.totalCost}',
                            isHighlighted: true,
                          ),
                      ],
                    ),

                  if (booking.bookingStatusCode == 'X' ||
                      booking.bookingStatusCode == 'XC') ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.cancellationDetails,
                      icon: Icons.cancel_rounded,
                      children: [
                        if (booking.bookingStatusCode != null &&
                            (booking.bookingStatusCode == 'XC'))
                          _buildInfoRow(
                            localization.cancelledBy,
                            localization.customer,
                          ),
                        if (booking.bookingStatusCode != null &&
                            (booking.bookingStatusCode == 'X'))
                          _buildInfoRow(
                            localization.cancelledBy,
                            localization.serviceProvider,
                          ),

                        if (booking.cancellationReason != null &&
                            (booking.cancellationReason ?? "").isNotEmpty)
                          _buildInfoRow(
                            localization.cancellationReason,
                            booking.cancellationReason ?? "",
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
                    ),
                  ],

                  if (booking.bookingStatusCode == 'C')
                    const SizedBox(height: 16),
                  if (booking.review != null)
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.customerReview,
                      icon: Icons.star_rounded,
                      children: [
                        _buildRatingRow(
                          localization.rating,
                          (booking.review!.rating ?? 0.0).toDouble(),
                        ),
                        if (booking.review!.review.isNotEmpty)
                          _buildInfoRow(
                            localization.review,
                            booking.review!.review,
                          ),
                        if (booking.review!.tipAmount != null &&
                            booking.review!.tipAmount! > 0)
                          _buildInfoRow(
                            localization.tipAmount,
                            '${localization.sar} ${booking.review!.tipAmount!.toStringAsFixed(1)}',
                          ),
                        if (booking.review!.createdAt != null)
                          _buildInfoRow(
                            localization.reviewedOn,
                            formatDateTime(
                              booking.review!.createdAt!.toDate(),
                              AppLocalizations.of(context)?.localeName ?? '',
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  _buildCompletionDataCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionDataCard(BuildContext context) {
    if (booking.completionData == null) {
      return const SizedBox.shrink();
    }

    final completionData = booking.completionData!;

    return _buildSectionCard(
      context: context,
      hasChat: false,
      title: AppLocalizations.of(context)!.completionDetails,
      icon: Icons.check_circle,
      children: [
        if (booking.paymentCompleted) ...[
          _buildInfoRow(
            AppLocalizations.of(context)!.transactionId,
            booking.orderId ?? "",
          ),
        ],

        _buildInfoRow(
          AppLocalizations.of(context)!.invoiceType,
          completionData.mode == 0
              ? AppLocalizations.of(context)!.inspection
              : AppLocalizations.of(context)!.fullService,
        ),
        if (booking.bookingStatusCode.toLowerCase() == 'c' &&
            booking.paymentCompleted) ...{
          _buildInfoRow(
            AppLocalizations.of(context)!.paymentMode,
            booking.paymentModeCode.toLowerCase() == 'c'
                ? AppLocalizations.of(context)!.card
                : booking.paymentModeCode.toLowerCase() == 'a'
                ? AppLocalizations.of(context)!.applePay
                : AppLocalizations.of(context)!.cashPayment,
          ),
        },

        // Upload Files
        if (completionData.fileUrls.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context)!.uploadFilesTitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildFileLinks(context, completionData.fileUrls),
        ],

        // Service Items
        if (completionData.serviceItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.serviceItems,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(),
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
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'x${entry.value.quantity.toInt()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  '${AppLocalizations.of(context)!.sar} ${entry.value.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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

        // Service Cost
        if (completionData.serviceCost > 0) ...[
          const SizedBox(height: 12),
          _buildCostRow(
            context,
            label: AppLocalizations.of(context)!.serviceCost,
            amount: completionData.serviceCost,
          ),
        ],

        _buildCostRow(
          context,
          label: AppLocalizations.of(context)!.inspectionFee,
          amount: booking.service.price ?? 0.0,
        ),

        // Total Cost
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
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${AppLocalizations.of(context)!.sar} ${completionData.totalCost.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCostRow(
    BuildContext context, {
    required String label,
    required double amount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Text(
          '${AppLocalizations.of(context)!.sar} ${amount.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
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
                  border: Border.all(),
                ),
                child: Row(
                  children: [
                    Icon(_getFileIcon(entry.value), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getFileName(entry.value),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new, size: 16),
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
    return "file ${int.tryParse((fileUrl.split('/').last.split('?').first.split("_").elementAt(3).substring(0, 1)))! + 1}${(fileUrl.split('/').last.split('?').first.split("_").elementAt(3).substring(1))}";
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.issueMedia,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (booking.issueImage != null && booking.issueImage!.isNotEmpty)
              const SizedBox(height: 20),

            // Images Section
            if (booking.issueImage != null && booking.issueImage!.isNotEmpty)
              Text(
                AppLocalizations.of(context)!.image,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            const SizedBox(height: 8),
            if (booking.issueImage != null && booking.issueImage!.isNotEmpty)
              GestureDetector(
                onTap: () => _showFullScreenImage(booking.issueImage!, context),
                child: Container(
                  height: MediaQuery.of(context).size.width * 0.4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: booking.issueImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: Center(child: Loader(size: 12)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.failedToLoadImage,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (booking.issueVideo != null && booking.issueVideo!.isNotEmpty)
              const SizedBox(height: 16),

            if (booking.issueVideo != null && booking.issueVideo!.isNotEmpty)
              Text(
                AppLocalizations.of(context)!.video,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            if (booking.issueVideo != null && booking.issueVideo!.isNotEmpty)
              const SizedBox(height: 8),
            if (booking.issueVideo != null && booking.issueVideo!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: CachedVideoPlayer(videoUrl: booking.issueVideo!),
              ),
          ],
        ),
      ),
    );
  }

  getLocalizedPaymentMode(String code, AppLocalizations localization) {
    switch (code) {
      case 'C':
        return localization.cards;
      case 'A':
        return localization.applePay;
      case 'O':
        return localization.cashPayment;
      default:
        return localization.unknown;
    }
  }

  Widget _buildStatusBadge(AppLocalizations localization) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (booking.bookingStatusCode) {
      case 'P':
        statusColor = Colors.orange;
        statusText = localization.pending;
        statusIcon = Icons.schedule;
        break;
      case 'A':
        statusColor = Colors.blue;
        statusText = localization.accepted;
        statusIcon = Icons.check_circle;
        break;
      case 'R':
        statusColor = Colors.red;
        statusText = localization.rejected;
        statusIcon = Icons.cancel;
        break;
      case 'C':
        if (booking.paymentCompleted == true) {
          statusColor = Colors.green;
          statusText = localization.completed;
          statusIcon = Icons.check_circle;
        } else {
          statusColor = Colors.deepOrange;
          statusText = localization.paymentPending;
          statusIcon = Icons.wallet;
        }

        break;
      case 'X':
        statusColor = Colors.red;
        statusText = localization.cancelled;
        statusIcon = Icons.cancel;
        break;
      case 'XC':
        statusColor = Colors.red;
        statusText = localization.cancelled;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = localization.unknown;
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool hasChat,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blue1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.blue1, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (hasChat) ...{
                const Spacer(),
                if (booking.chatroomId.isNotEmpty)
                  StreamBuilder<int>(
                    stream: ChatService().getUnreadCountStream(
                      booking.chatroomId,
                    ),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return SizedBox(
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatId: booking.chatroomId,
                                  participantName:
                                      booking.agent!.name ?? 'Technician',
                                  participantId: booking.agent!.uid ?? '',
                                  participantPhoto:
                                      booking.agent!.profileUrl ?? '',
                                  customerName:
                                      booking.customer.name ?? 'Customer',
                                  customerPhoto: '',
                                  bookingId: booking
                                      .id, // Customer model does not have profileUrl yet
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.secondary,
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
              },
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlighted = false,
    bool needCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: needCopy
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: isHighlighted ? AppColors.blue1 : Colors.black87,
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

  Widget _buildRatingRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating.floor()
                        ? Icons.star
                        : index < rating
                        ? Icons.star_half
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  '(${rating.toStringAsFixed(1)})',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
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

  Widget _buildClickableInfoRow(
    String label,
    String value, {
    required VoidCallback onTap,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.blue1, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: isHighlighted
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: AppColors.blue1,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Handle the case where the URL can't be launched
        debugPrint('Could not launch $url');
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
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
              boundaryMargin: EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 24,
                    child: Loader(size: 14, color: Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 100, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.failedToLoadImage,
                        style: TextStyle(color: Colors.white),
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
}
