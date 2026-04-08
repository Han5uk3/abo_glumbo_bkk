import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
          shape: shape,
        ),
      ),
    );
  }
}

class CategoryGridShimmer extends StatelessWidget {
  const CategoryGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisExtent: 125,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Center(
            child: Container(
              height: 105,
              width: 105,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ShimmerLoader(width: 40, height: 40, borderRadius: 20),
                  const SizedBox(height: 10),
                  const ShimmerLoader(width: 60, height: 10, borderRadius: 4),
                ],
              ),
            ),
          );
        },
        childCount: 6,
      ),
    );
  }
}

class ServiceTileShimmer extends StatelessWidget {
  const ServiceTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const ShimmerLoader(width: 60, height: 60, borderRadius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoader(width: 150, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerLoader(width: 100, height: 10, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
