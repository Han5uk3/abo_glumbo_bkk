import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final detaliLocation = worker.detailedLocation;
    final cityName = Directionality.of(context) == TextDirection.rtl
        ? detaliLocation?.governorateAr ?? ''
        : detaliLocation?.governorateEn ?? '';
    final neighborhoodName = Directionality.of(context) == TextDirection.rtl
        ? detaliLocation?.neighborhoodAr ?? ''
        : detaliLocation?.neighborhoodEn ?? '';


    // final services = worker.jobRoles ?? [];
    final inspectionFee = service.price ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
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
                  child: Text(
                    worker.name ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: AppColors.primary, size: 24),
              ],
            ),

            const SizedBox(height: 12),

            // Rating
            _InfoRow(
              icon: '⭐',
              text:
                  '$rating ($reviewCount ${AppLocalizations.of(context)!.reviews})',
            ),

            const SizedBox(height: 6),

            // Distance
            _InfoRow(icon: '📍', text: '$neighborhoodName | $cityName '),

            const SizedBox(height: 6),

            // Completed Orders
            _InfoRow(
              icon: '📦',
              text:
                  '${AppLocalizations.of(context)!.completedOrders}: $completedJobs',
            ),

            const SizedBox(height: 6),

            // Inspection Fee
            _InfoRow(
              icon: '💵',
              text:
                  '${AppLocalizations.of(context)!.inspectionFee}: $inspectionFee ${AppLocalizations.of(context)!.sar}',
            ),

            const SizedBox(height: 6),

            // Services
            if (localizedJobRoles.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🪪 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      '${AppLocalizations.of(context)!.services}: ${localizedJobRoles.join(' • ')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
