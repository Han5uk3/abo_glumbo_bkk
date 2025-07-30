import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:flutter/material.dart';

Future<bool?> showServiceBottomSheet(
  BuildContext context, {
  required ServiceModel service,
}) async {
  bool? res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      return ServiceInfoSheet(service: service);
    },
  );

  return res;
}

class ServiceInfoSheet extends StatefulWidget {
  final ServiceModel service;
  const ServiceInfoSheet({super.key, required this.service});

  @override
  State<ServiceInfoSheet> createState() => _ServiceInfoSheetState();
}

class _ServiceInfoSheetState extends State<ServiceInfoSheet> {
  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: safePadding.bottom + 3),
      child: ServiceTile(
        service: widget.service,
        // onFavoritePressed: () {},
        // onFavPressed: () => setFavorite(widget.service),
      ),
    );
  }
}
