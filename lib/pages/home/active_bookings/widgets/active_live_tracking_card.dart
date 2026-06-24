import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class TrackingCard extends StatelessWidget {
  final int etaMinutes;
  final String fromLocation;
  final String toLocation;
  final VoidCallback onTrack;
  final BookingModel booking;
  final bool isCalculating;

  const TrackingCard({
    super.key,
    required this.etaMinutes,
    required this.fromLocation,
    required this.toLocation,
    required this.onTrack,
    required this.booking,
    this.isCalculating = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTrack,
      child: Container(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Technician Info & Map Visualization
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Technician Name
                        Text(
                          booking.agent?.name ?? 'Unknown Technician',
                          style: DMSansFont.textStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Service Name
                        Text(
                          booking.service.nameLocalized(
                                languageCode: AppLocalizations.of(
                                  context,
                                )!.localeName,
                              ) ??
                              booking.service.name ??
                              '',
                          style: DMSansFont.textStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Mini Map Visualization (Route Line)
                      ],
                    ),
                  ),

                  // ETA Display
                  Container(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (etaMinutes == -1) ...[
                          // Location error indicator
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 32,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.locationError,
                            style: DMSansFont.textStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else if (isCalculating) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              AppLocalizations.of(context)!.calculating,
                              style: DMSansFont.textStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            etaMinutes > 60
                                ? (etaMinutes / 60)
                                      .toStringAsFixed(1)
                                      .replaceAll(RegExp(r'\.0$'), '')
                                : '$etaMinutes',
                            style: DMSansFont.textStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            etaMinutes > 60
                                ? (etaMinutes / 60) >= 2
                                      ? AppLocalizations.of(context)!.hours
                                      : AppLocalizations.of(context)!.hour
                                : etaMinutes.toString().length == 1
                                ? AppLocalizations.of(context)!.min
                                : AppLocalizations.of(context)!.mins,
                            style: DMSansFont.textStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMiniMapRoute(),
            ),
            SizedBox(height: 16),

            // Divider
            Divider(height: 1, color: Colors.grey[200]),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.tapForLiveLocationTracking,
                    style: DMSansFont.textStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMapRoute() {
    return Row(
      children: [
        // Technician Icon (Start)
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, size: 14, color: Colors.black54),
        ),

        // Dashed Line
        Expanded(
          child: SizedBox(
            height: 2,
            child: CustomPaint(
              painter: DashedLinePainter(
                color: Colors.red,
                dashWidth: 4,
                dashSpace: 3,
              ),
            ),
          ),
        ),

        // Customer Icon (End)
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.home, size: 14, color: AppColors.primary),
        ),
      ],
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({
    required this.color,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
