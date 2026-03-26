// ignore_for_file: deprecated_member_use

import 'package:abo_glumbo_bbk/common_widgets/cached_video_player.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/date_formatter.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/bookings/timeline.dart';
import 'package:abo_glumbo_bbk/pages/chat/chat.dart';
import 'package:abo_glumbo_bbk/services/chat_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/poppins_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<void> showBookingDetailsBottomSheet(
  BuildContext context, {
  required BookingModel booking,
  VoidCallback? onRefresh,
  bool isWarranty = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BookingDetailsBottomSheet(
      booking: booking,
      onRefresh: onRefresh,
      isWarranty: isWarranty,
    ),
  );
}

class BookingDetailsBottomSheet extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onRefresh;
  final bool isWarranty;

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
    this.onRefresh,
    this.isWarranty = false,
  });

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
        Text(text, style: TextStyle(color: AppColors.black1, fontSize: 10.5)),
      ],
    );
  }

  Widget _buildInfoRows(
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
                    style: DMSansFont.textStyle(
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
          SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBadge(localization),
                  const SizedBox(height: 20),

                  Container(
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      // border: Border.all(color: Colors.black.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(8),
                      color: Color(0xffEAF1FF).withOpacity(0.50),
                    ),
                    margin: const EdgeInsets.only(
                      left: 0,
                      right: 0,
                      bottom: 14,
                    ),
                    padding: EdgeInsets.all(13),
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
                              SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // SizedBox(width: 10),

                                  // ClipRRect(
                                  //   borderRadius: BorderRadius.circular(4),
                                  //   child:
                                  //       (booking.service.image != null &&
                                  //           booking.service.image!.isNotEmpty &&
                                  //           Uri.tryParse(
                                  //                 booking.service.image!,
                                  //               ) !=
                                  //               null &&
                                  //           Uri.tryParse(
                                  //             booking.service.image!,
                                  //           )!.hasAbsolutePath)
                                  //       ? CachedNetworkImage(
                                  //           imageUrl: booking.service.image!,
                                  //           height: 50,
                                  //           width: 50,
                                  //           fit: BoxFit.cover,
                                  //           placeholder: (context, url) =>
                                  //               Container(
                                  //                 color: Colors.grey[200],
                                  //               ),
                                  //           errorWidget:
                                  //               (
                                  //                 context,
                                  //                 url,
                                  //                 error,
                                  //               ) => const Icon(
                                  //                 Icons.broken_image_outlined,
                                  //               ),
                                  //         )
                                  //       : Container(
                                  //           height: 50,
                                  //           width: 50,
                                  //           color: Colors.grey[300],
                                  //           child: const Center(
                                  //             child: Icon(
                                  //               Icons.image_not_supported,
                                  //               color: Colors.grey,
                                  //               size: 20,
                                  //             ),
                                  //           ),
                                  //         ),
                                  // ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Text("Booking ID"),
                                        Wrap(
                                          children: [
                                            Text(
                                              "#${booking.id}",
                                              style: TextStyle(fontSize: 11),
                                            ),

                                            // Text(
                                            //   booking.service.nameLocalized(
                                            //         languageCode:
                                            //             AppLocalizations.of(
                                            //               context,
                                            //             )?.localeName ??
                                            //             'en',
                                            //       ) ??
                                            //       '',
                                            //   maxLines: 2,
                                            //   overflow: TextOverflow.ellipsis,
                                            //   style: DMSansFont.textStyle(
                                            //     fontWeight: FontWeight.bold,
                                            //     fontSize: 13,
                                            //     color: Colors.black,
                                            //   ),
                                            // ),
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
                                        "${booking.bookingStatusCode == "C" ? booking.completionData?.totalCost : booking.service.price} ${AppLocalizations.of(context)!.sar}",
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

                              SizedBox(height: 5),
                            ],
                          ),
                        ),
                        Divider(thickness: 0.5, color: Colors.black),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [_buildTimestampText(context)],
                        ),
                      ],
                    ),
                  ),

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
                      SizedBox(height: 5),
                      Divider(thickness: 0.5, color: Colors.black),
                      SizedBox(height: 10),
                      if (booking.service.price != null)
                        // _buildInfoRow(
                        //   localization.inspectionFee,
                        //   '${localization.sar} ${booking.service.price}',
                        // ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${localization.inspectionFee}\t\t  ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${localization.sar} ${booking.service.price}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff2ECC71),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                            style: DMSansFont.textStyle(
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
                  const SizedBox(height: 16),
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
                          localization.location,
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
                      booking.bookingStatusCode == 'XC' ||
                      booking.bookingStatusCode == 'R') ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      hasChat: false,
                      title: localization.cancellationDetails,
                      icon: Icons.cancel_rounded,
                      children: [
                        if (booking.bookingStatusCode != null &&
                            (booking.bookingStatusCode == 'XC')) ...{
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
                        },

                        if (booking.bookingStatusCode != null &&
                            (booking.bookingStatusCode == 'X')) ...[
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
                        if (booking.bookingStatusCode != null &&
                            (booking.bookingStatusCode == 'R')) ...{
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
                        },

                        if (booking.cancellationReason != null &&
                            (booking.cancellationReason ?? "").isNotEmpty)
                          _buildInfoRow(
                            localization.cancellationReason,
                            booking.cancellationReason ?? "",
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
                  if (isWarranty) ...{
                    const SizedBox(height: 16),
                    if (booking.warranty != null)
                      _buildWarrantyDataCard(context),
                  },

                  buildBookingTimelineCard(
                    context,
                    textTheme,
                    colorScheme,
                    isWarranty,
                    booking,
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

  Future<void> _openOrCreateChat(BuildContext context) async {
    final chatService = ChatService();

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          // constraints: BoxConstraints(minWidth: 100),
          backgroundColor: Colors.white,
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

      // Check if chatroom exists
      if (booking.chatroomId.isNotEmpty) {
        chatId = booking.chatroomId;
      } else {
        // Create new chatroom
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        chatId = await chatService.createChat(
          booking.id,
          booking.agent!.uid ?? '',
          booking.agent!.name ?? 'Technician',
          booking.agent!.profileUrl ?? '',
          booking.customer.name ?? 'Customer',
          '', // Customer photo - update if available
          'customer',
        );

        await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
          'chatroomId': chatId,
        });
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Open chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              participantName: booking.agent!.name ?? 'Technician',
              participantId: booking.agent!.uid ?? '',
              participantPhoto: booking.agent!.profileUrl ?? '',
              customerName: booking.customer.name ?? 'Customer',
              customerPhoto: '',
              bookingId: booking.id,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
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
              getExpiryDate(booking.warranty!.createdAt!),
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
    switch (status.toLowerCase()) {
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

  DateTime getExpiryDate(DateTime createdAt) {
    final expiryDate = createdAt.add(const Duration(days: 7));
    return expiryDate;
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
            style: PoppinsFont.textStyle(
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
            style: PoppinsFont.textStyle(
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
                                  style: PoppinsFont.textStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'x${entry.value.quantity.toInt()}',
                                  style: PoppinsFont.textStyle(
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
                                  style: PoppinsFont.textStyle(
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
                style: PoppinsFont.textStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${AppLocalizations.of(context)!.sar} ${completionData.totalCost.toStringAsFixed(2)}',
                style: PoppinsFont.textStyle(
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
          style: PoppinsFont.textStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${AppLocalizations.of(context)!.sar} ${amount.toStringAsFixed(2)}',
          style: PoppinsFont.textStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
                        style: PoppinsFont.textStyle(
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
                  style: PoppinsFont.textStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
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
                      // Icon(Icons.image, color: Colors.grey[600]!),
                      SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.image,
                        style: PoppinsFont.textStyle(
                          fontSize: 14,
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
                  padding: EdgeInsets.all(8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: Row(
                    children: [
                      // Icon(
                      //   Icons.video_camera_back_rounded,
                      //   color: Colors.grey[600]!,
                      // ),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.video,
                        style: PoppinsFont.textStyle(
                          fontSize: 14,
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

  _showFullScreenVideo(String videoUrl, BuildContext context) {
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
            style: DMSansFont.textStyle(
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
                style: DMSansFont.textStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              if ((hasChat && booking.bookingStatusCode == 'A') ||
                  (hasChat &&
                      booking.warranty?.warrantyStatusCode == 'S' &&
                      isWarranty)) ...{
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
                        onTap: () => _openOrCreateChat(context),
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
              },
            ],
          ),

          const SizedBox(height: 5),
          Divider(thickness: 1, color: Color(0xffCAC4D0)),

          const SizedBox(height: 5),

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
              style: DMSansFont.textStyle(
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
              style: DMSansFont.textStyle(
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
              style: DMSansFont.textStyle(
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
                  style: DMSansFont.textStyle(
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
              style: DMSansFont.textStyle(
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
                        style: DMSansFont.textStyle(
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
