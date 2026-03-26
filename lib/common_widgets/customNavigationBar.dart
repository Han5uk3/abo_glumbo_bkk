// customNavigationBar.dart
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
    this.myBookingLabel = 'My Booking',
    this.accountLabel = 'Account',
  });

  @override
  Widget build(BuildContext context) {
    final List<NavigationItem> items = _buildNavigationItems();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = selectedIndex == index;

          return Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => onDestinationSelected(index),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: isSelected ? 22 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smooth icon color animation
                      TweenAnimationBuilder<Color?>(
                        duration: const Duration(milliseconds: 350),
                        tween: ColorTween(
                          begin: isSelected ? AppColors.grey : AppColors.bgWhite,
                          end: isSelected ? AppColors.bgWhite : AppColors.grey,
                        ),
                        builder: (context, color, child) {
                          return SvgPicture.asset(
                            item.iconPath,
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              color ?? AppColors.grey,
                              BlendMode.srcIn,
                            ),
                          );
                        },
                      ),
                      // Smooth width expansion for the text
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        child: !isSelected
                            ? const SizedBox.shrink()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.bgWhite,
                                    ),
                                    overflow: TextOverflow.clip,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ],
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
          label: myBookingLabel ?? 'My Booking',
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
