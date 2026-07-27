import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/styles/app_icons.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool isGuest;
  final String? homeLabel;
  final String? myBookingLabel;
  final String? accountLabel;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isGuest = false,
    this.homeLabel = 'Home',
    this.myBookingLabel = 'Bookings',
    this.accountLabel = 'Account',
  });

  @override
  Widget build(BuildContext context) {
    final List<NavigationItem> items = _buildNavigationItems();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          height: 60,
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDestinationSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.25)
                                : Colors.transparent,
                            blurRadius: isSelected ? 8 : 0,
                            offset: isSelected
                                ? const Offset(0, 4)
                                : Offset.zero,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<Color?>(
                            duration: const Duration(milliseconds: 300),
                            tween: ColorTween(
                              begin: isSelected ? AppColors.grey : Colors.white,
                              end: isSelected ? Colors.white : AppColors.grey,
                            ),
                            builder: (context, color, child) {
                              return SvgPicture.asset(
                                item.iconPath,
                                width: 18,
                                height: 18,
                                colorFilter: ColorFilter.mode(
                                  color ?? AppColors.grey,
                                  BlendMode.srcIn,
                                ),
                              );
                            },
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.fastOutSlowIn,
                            alignment: Alignment.centerLeft,
                            child: !isSelected
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      start: 8,
                                    ),
                                    child: Text(
                                      item.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  List<NavigationItem> _buildNavigationItems() {
    final List<NavigationItem> items = [
      NavigationItem(iconPath: AppIcons.homeNav, label: homeLabel ?? 'Home'),
    ];

    if (!isGuest) {
      items.add(
        NavigationItem(
          iconPath: AppIcons.myBookingNav,
          label: myBookingLabel ?? 'Bookings',
        ),
      );
    }

    items.add(
      NavigationItem(
        iconPath: AppIcons.profileNav,
        label: accountLabel ?? 'Account',
      ),
    );

    return items;
  }
}

class NavigationItem {
  final String iconPath;
  final String label;

  NavigationItem({required this.iconPath, required this.label});
}
