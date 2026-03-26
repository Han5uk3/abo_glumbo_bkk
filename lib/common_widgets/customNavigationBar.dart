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
    Key? key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isGuest = false,
    this.homeLabel = 'Home',
    this.myBookingLabel = 'My Booking',
    this.accountLabel = 'Account',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<NavigationItem> items = _buildNavigationItems();

    return Container(
      height: 40, // Increased height for better visibility
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDestinationSelected(index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 2),

                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with container
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(0),
                          // decoration: BoxDecoration(
                          //   color: isSelected
                          //       ? AppColors.bgWhite
                          //       : Colors.transparent,
                          //   borderRadius: BorderRadius.circular(12),
                          // ),
                          child: SvgPicture.asset(
                            item.iconPath,
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              isSelected
                                  ? AppColors.bgWhite
                                  : Colors.grey.shade500,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Label
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.bgWhite
                                : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ],
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
