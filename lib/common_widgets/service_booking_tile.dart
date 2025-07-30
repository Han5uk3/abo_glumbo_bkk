import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/sheets/booking_details.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceBookingTile extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onRefresh;
  final VoidCallback onReviewButtonPressed;
  const ServiceBookingTile({
    super.key,
    required this.booking,
    required this.onRefresh,
    required this.onReviewButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showBookingDetailsBottomSheet(
        context,
        booking: booking,
        onRefresh: onRefresh,
      ),
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
        padding: const EdgeInsets.all(13),
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
                  Text(
                    booking.service.nameLocalized(
                          languageCode:
                              AppLocalizations.of(context)?.localeName ?? 'en',
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
                    booking.service.descriptionLocalized(
                          languageCode:
                              AppLocalizations.of(context)?.localeName ?? 'en',
                        ) ??
                        '',
                    style: GoogleFonts.dmSans(
                      color: Colors.black45,
                      fontSize: 12,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (booking.bookingStatusCode == "C") ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 23,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: AppColors.yellow,
                        ),
                        onPressed: booking.review == null
                            ? onReviewButtonPressed
                            : null,
                        child: Text(
                          booking.review == null
                              ? AppLocalizations.of(context)?.writeAReview ?? ''
                              : AppLocalizations.of(context)?.reviewSubmitted ??
                                    '',
                          style: GoogleFonts.dmSans(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${booking.service.price} ${AppLocalizations.of(context)?.sar}",
                  style: GoogleFonts.dmSans(
                    color: AppColors.green1,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                if (booking.bookingStatusCode == "P")
                  SizedBox(
                    height: 23,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () async {
                        // bool? res = await showBookingCancelDialog(
                        //   context,
                        //   booking: booking,
                        // );
                        // if (res == true) {
                        //   // refresh the page
                        //   onRefresh.call();
                        // }
                      },
                      child: Text(
                        AppLocalizations.of(context)?.cancel ?? '',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: AppColors.grey3,
                        ),
                      ),
                    ),
                  )
                else if (booking.bookingStatusCode == "C")
                  Container(
                    height: 23,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.green2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)?.completed ?? '',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        color: AppColors.green2,
                      ),
                    ),
                  )
                else if (booking.bookingStatusCode == "X")
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
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        color: AppColors.red,
                      ),
                    ),
                  )
                else if (booking.bookingStatusCode == "R")
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
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        color: AppColors.darkGrey,
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
}
