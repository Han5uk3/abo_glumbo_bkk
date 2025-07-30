import 'package:abo_glumbo_bbk/styles/app_images.dart';
import 'package:flutter/material.dart';

class LocationCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  const LocationCard({super.key, this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color.fromARGB(255, 232, 232, 232),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: Image.asset(AppImages.livelocationIcon),
              ),
              Text(title ?? 'Location Title'),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle ?? 'Location Subtitle'),
        ],
      ),
    );
  }
}
