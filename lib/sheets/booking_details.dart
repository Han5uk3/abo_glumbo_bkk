// ignore_for_file: deprecated_member_use
import 'package:abo_glumbo_bbk/common_widgets/cached_video_player.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    _buildIssueMediaCard(context, textTheme, colorScheme),
                  },
                  const SizedBox(height: 16),
                  if (customerSelectedAddress != null &&
                      customerSelectedAddress.buildingNumber.isNotEmpty)
                    _buildSectionCard(
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
                      title: localization.workerInfo,
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

                        if (booking.paymentCompleted)
                          _buildInfoRow(
                            localization.paymentMethod,
                            getLocalizedPaymentMode(
                              booking.paymentModeCode,
                              localization,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (booking.notes.isNotEmpty)
                    _buildSectionCard(
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

                  if (booking.bookingStatusCode == 'X' ||
                      booking.bookingStatusCode == 'XC') ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        return localization.cashOnHands;
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
        statusColor = Colors.green;
        statusText = localization.completed;
        statusIcon = Icons.check_circle;
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
    required String title,
    required IconData icon,
    required List<Widget> children,
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
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: isHighlighted ? AppColors.blue1 : Colors.black87,
              ),
            ),
          ),
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
