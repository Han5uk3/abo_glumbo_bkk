import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/helpers/location_helper.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';

class WorkerCard extends StatelessWidget {
  final UserModel worker;
  final double rating;
  final int reviewCount;
  final ServiceModel service;
  final int completedJobs;
  final AddressModel customerAddress;
  final bool isSelected;
  final bool isBusy;
  final bool isTooFar;
  final List<String> localizedJobRoles;

  const WorkerCard({
    super.key,
    required this.worker,
    required this.isSelected,
    required this.customerAddress,
    required this.rating,
    required this.completedJobs,
    required this.service,
    required this.reviewCount,
    required this.localizedJobRoles,
    this.isBusy = false,
    this.isTooFar = false,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    // Calculate distance between the booking address and technician's last known location
    double? distance;
    if (customerAddress.lat != null &&
        customerAddress.lon != null &&
        worker.lastKnownLocation != null) {
      distance = LocationHelper.calculateDistance(
        customerAddress.lat!,
        customerAddress.lon!,
        worker.lastKnownLocation!.latitude,
        worker.lastKnownLocation!.longitude,
      );
    }

    return Opacity(
      opacity: (isTooFar || isBusy) ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: (isTooFar || isBusy) ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isTooFar || isBusy)
                ? Colors.red.shade200
                : isSelected
                ? AppColors.primary
                : Colors.grey.shade300,
            width: isSelected && !(isTooFar || isBusy) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isTooFar || isBusy)
                  ? Colors.transparent
                  : isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Name and Specialty
                  Row(
                    children: [
                      Text('🧑‍🔧', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: worker.name ?? 'Unknown'),
                              if (worker.tier != null &&
                                  worker.tier!.isNotEmpty)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.workspace_premium,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isTooFar
                                ? Colors.grey.shade500
                                : Colors.grey.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected && !isTooFar)
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      if (isBusy)
                        Text(
                          locale.technicianIsBusy,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Distance
                  if (distance != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Text(
                            isTooFar ? '⚠️ ' : '📍 ',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Expanded(
                            child: Text(
                              '${locale.within} ${distance.toStringAsFixed(1)} ${locale.km} radius',
                              style: TextStyle(
                                fontSize: 14,
                                color: isTooFar
                                    ? Colors.red.shade600
                                    : Colors.grey.shade700,
                                fontWeight: isTooFar
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                height: 1.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Rating
                  _InfoRow(
                    icon: '⭐',
                    text: '$rating ($reviewCount ${locale.reviews})',
                  ),

                  const SizedBox(height: 6),

                  // // Completed Orders
                  // _InfoRow(
                  //   icon: '📦',
                  //   text:
                  //       '${locale.completedOrders}: $completedJobs',
                  // ),

                  // const SizedBox(height: 6),

                  // Services
                  // if (localizedJobRoles.isNotEmpty)
                  //   Row(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text('🪪 ', style: TextStyle(fontSize: 16)),
                  //       Expanded(
                  //         child: Text(
                  //           '${locale.services}: ${localizedJobRoles.join(' • ')}',
                  //           style: TextStyle(
                  //             fontSize: 14,
                  //             color: Colors.grey.shade700,
                  //             height: 1.4,
                  //           ),
                  //           maxLines: 2,
                  //           overflow: TextOverflow.ellipsis,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                ],
              ),
            ),

            // "Too Far Away" badge overlay
            if (isTooFar)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locale.tooFarAway,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
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
}

// Simple info row widget
class _InfoRow extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$icon ', style: TextStyle(fontSize: 16)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
