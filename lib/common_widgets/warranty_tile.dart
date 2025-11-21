import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/sheets/booking_details.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WarrantyTile extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onPressed;
  final bool isRequested;
  const WarrantyTile({
    super.key,
    required this.booking,
    required this.onPressed,
    required this.isRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
      padding: const EdgeInsets.all(13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showBookingDetailsBottomSheet(
              context,
              booking: booking,
              onRefresh: () {},
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child:
                      (booking.service.image != null &&
                          booking.service.image!.isNotEmpty &&
                          Uri.tryParse(booking.service.image!) != null &&
                          Uri.tryParse(booking.service.image!)!.hasAbsolutePath)
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
                const SizedBox(width: 17),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            booking.service.nameLocalized(
                                  languageCode:
                                      AppLocalizations.of(
                                        context,
                                      )?.localeName ??
                                      'en',
                                ) ??
                                '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "${booking.bookingStatusCode == "C" ? booking.completionData?.totalCost : booking.service.price} ${AppLocalizations.of(context)!.sar}",
                            style: GoogleFonts.dmSans(
                              color: AppColors.green1,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        booking.service.descriptionLocalized(
                              languageCode:
                                  AppLocalizations.of(context)?.localeName ??
                                  'en',
                            ) ??
                            '',
                        style: GoogleFonts.dmSans(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Conditional button display based on warranty status
          if (isRequested == false && booking.warranty?.completed != true)
            // Show request button when not requested and not completed
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(4),
                child: Ink(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(
                            context,
                          )?.requestRepairUnderWarranty ??
                          '',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (isRequested == true && booking.warranty?.completed != true)
            // Show pending status when requested but not completed
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_outlined, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)?.pending ??
                        'Warranty Request Pending',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            )
          else if (booking.warranty?.completed == true)
            // Show completed status when warranty is completed
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)?.completed ??
                        'Warranty Completed',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
