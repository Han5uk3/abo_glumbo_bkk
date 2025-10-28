import 'dart:developer' show log;
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/worker_card.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';

class WorkerList extends StatefulWidget {
  final String category;
  final AddressModel? selectedAddress;
  final ValueNotifier<int?> selectedIndexNotifier;
  final Function(UserModel) onWorkerSelected;

  const WorkerList({
    super.key,
    required this.category,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
  });

  @override
  State<WorkerList> createState() => _WorkerListState();
}

class _WorkerListState extends State<WorkerList> {
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: AppServices.getWorkersByRoles(widget.category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Loader(color: AppColors.primary));
        }

        if (snapshot.hasError) {
          print("Debug - Stream Error: ${snapshot.error}");
          return const Center(child: Text("An error occurred"));
        }

        final data = snapshot.data ?? [];
        if (widget.selectedAddress != null) {
          data.sort((a, b) {
            final addressLat = widget.selectedAddress!.lat ?? 0.0;
            final addressLon = widget.selectedAddress!.lon ?? 0.0;

            final distanceA = calculateDistance(
              a.liveLocation?.latitude ?? 0.0,
              a.liveLocation?.longitude ?? 0.0,
              addressLat,
              addressLon,
            );
            final distanceB = calculateDistance(
              b.liveLocation?.latitude ?? 0.0,
              b.liveLocation?.longitude ?? 0.0,
              addressLat,
              addressLon,
            );
            return distanceA.compareTo(distanceB);
          });
        }

        return ListView.builder(
          padding: EdgeInsets.only(top: 16),
          shrinkWrap: true,
          itemCount: data.length,
          itemBuilder: (context, index) {
            final worker = data[index];

            return ValueListenableBuilder(
              valueListenable: widget.selectedIndexNotifier,
              builder: (context, selectedIndex, child) {
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    widget.selectedIndexNotifier.value = index;
                    widget.onWorkerSelected(worker);
                  },
                  child: WorkerCard(
                    worker: worker,
                    customerAddress:
                        widget.selectedAddress ??
                        AddressModel(
                          id: '',
                          fullName: '',
                          buildingNumber: '',
                          phoneNumber: '',
                          
                        ),
                    isSelected: isSelected,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
