import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/styles/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking.dart';

/// returns true if refresh is needed
Future<bool?> showBookingCancelDialog(
  BuildContext context, {
  required BookingModel booking,
  required TextEditingController? controller,
}) async {
  bool? res = await showDialog(
    barrierDismissible: false,
    useSafeArea: false,
    context: context,
    builder: (BuildContext context) {
      return CancelBookingDialogWidget(
        booking: booking,
        reasonController: controller,
      );
    },
  );

  return res;
}

class CancelBookingDialogWidget extends StatefulWidget {
  const CancelBookingDialogWidget({
    super.key,
    required this.booking,
    this.reasonController,
  });
  final BookingModel booking;
  final TextEditingController? reasonController;

  @override
  State<CancelBookingDialogWidget> createState() =>
      _CancelBookingDialogWidgetState();
}

class _CancelBookingDialogWidgetState extends State<CancelBookingDialogWidget> {
  bool isCanceling = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.all(0),
      content: SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.loose,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0).copyWith(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppIcons.cancelHexagon,
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8),
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(
                                context,
                              )?.areYouSureToWantCancelBooking ??
                              '',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: widget.reasonController,
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(
                                  context,
                                )?.reasonForCancellation ??
                                'Reason for cancellation',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (!isCanceling)
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  AppLocalizations.of(context)?.no ?? '',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (!isCanceling) const SizedBox(width: 15),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                backgroundColor: AppColors.secondary,
                              ),
                              onPressed:
                                  (isCanceling &&
                                      widget.reasonController!.text.isNotEmpty)
                                  ? () {}
                                  : () => Navigator.pop(context, true),
                              child:
                                  (isCanceling &&
                                      widget.reasonController!.text.isNotEmpty)
                                  ? Loader()
                                  : Text(
                                      AppLocalizations.of(context)?.yesCancel ??
                                          '',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
