import 'dart:math';

import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';

class WorkerCard extends StatelessWidget {
  final UserModel worker;
  final AddressModel customerAddress;
  final bool isSelected;

  const WorkerCard({
    super.key,
    required this.worker,
    required this.isSelected,
    required this.customerAddress,
  });

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.00; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = R * c;

    return distance;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final distance = calculateDistance(
      worker.liveLocation?.latitude ?? 0.0,
      worker.liveLocation?.longitude ?? 0.0,
      customerAddress.lat ?? 0.0,
      customerAddress.lon ?? 0.0,
    );

    return Card(
      elevation: isSelected ? 8.0 : 2.0,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          width: 2,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: worker.profileUrl != null
                  ? NetworkImage(worker.profileUrl!)
                  : AssetImage('assets/images/profile_placeholder.jpg')
                        as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker.jobRoles?.join(', ') ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${AppLocalizations.of(context)!.within} ${distance.toStringAsFixed(1)} ${AppLocalizations.of(context)!.km}",
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
