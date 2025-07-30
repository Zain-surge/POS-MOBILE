import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:epos/settings_screen.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';
import 'package:epos/order_counts_provider.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onItemSelected;
  final bool showDivider;

  const CustomBottomNavBar({
    Key? key,
    required this.selectedIndex,
    this.onItemSelected,
    this.showDivider = false,
  }) : super(key: key);

  String _getNotificationCount(int index, Map<String, int> activeOrdersCount) {
    switch (index) {
      case 0: // Takeaway
        int count = activeOrdersCount['takeaway'] ?? 0;
        return count > 0 ? count.toString() : '';
      case 1: // Dine In
        int count = activeOrdersCount['dinein'] ?? 0;
        return count > 0 ? count.toString() : '';
      case 2: // Delivery
        int count = activeOrdersCount['delivery'] ?? 0;
        return count > 0 ? count.toString() : '';
      case 3: // Website
        int count = activeOrdersCount['website'] ?? 0;
        return count > 0 ? count.toString() : '';
      default:
        return '';
    }
  }

  Widget _navItem(
      BuildContext context,
      String image,
      int index, {
        String? notification,
        Color? color,
        required VoidCallback onTap,
      }) {
    bool isSelected = selectedIndex == index;
    String displayImage = _getDisplayImage(image, isSelected);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          onItemSelected?.call(index);
          onTap();
        },
        child: Container(
          width: 140, // Fixed width for consistent rectangular background
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                'assets/images/$displayImage',
                width: (displayImage == 'Delivery.png' || displayImage == 'Deliverywhite.png') ? 92 : 60,
                height: (displayImage == 'Delivery.png' || displayImage == 'Deliverywhite.png') ? 92 : 60,
                color: isSelected ? Colors.white : const Color(0xFF616161),
              ),
              if (notification != null && notification.isNotEmpty)
                Positioned(
                  top: -2,
                  right: (displayImage == 'Delivery.png' || displayImage == 'Deliverywhite.png') ? 14 : 30,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color ??  const Color(0xFFFFE26B),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    child: Text(
                      notification,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayImage(String image, bool isSelected) {
    if (isSelected) {
      if (image == 'TakeAway.png') {
        return 'TakeAwaywhite.png';
      } else if (image == 'DineIn.png') {
        return 'DineInwhite.png';
      } else if (image == 'Delivery.png') {
        return 'Deliverywhite.png';
      } else if (image == 'web.png') {
        return 'webwhite.png';
      } else if (image == 'home.png') {
        return 'home.png';
      }else if (image == 'More.png') {
        return 'More.png';
      }else if (image.contains('.png')) {
        return image.replaceAll('.png', 'white.png');
      }
    } else {
      if (image == 'TakeAwaywhite.png') {
        return 'TakeAway.png';
      } else if (image == 'DineInwhite.png') {
        return 'DineIn.png';
      } else if (image == 'Deliverywhite.png') {
        return 'Delivery.png';
      } else if (image == 'web.png') {
        return 'web.png';
      } else if (image == 'home.png') {
        return 'home.png';
      }else if (image == 'More.png') {
        return 'More.png';
      } else if (image.contains('white.png')) {
        return image.replaceAll('white.png', '.png');
      }
    }
    return image;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderCountsProvider>(
      builder: (context, orderCountsProvider, child) {
        final activeOrdersCount = orderCountsProvider.activeOrdersCount;

        Widget navBar = Container(
          height: 80,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFB2B2B2),
                width: 1.2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navItem(
                  context,
                  'TakeAway.png',
                  0,
                  notification: _getNotificationCount(0, activeOrdersCount),
                  color: const Color(0xFFFFE26B),
                  onTap: () {
                    debugPrint("Navigating to Takeaway orders.");
                    if (selectedIndex != 0) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DynamicOrderListScreen(
                            orderType: 'takeaway',
                            initialBottomNavItemIndex: 0,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _navItem(
                  context,
                  'DineIn.png',
                  1,
                  notification: _getNotificationCount(1, activeOrdersCount),
                  color: const Color(0xFFFFE26B),
                  onTap: () {
                    debugPrint("Navigating to Dine-In orders.");
                    if (selectedIndex != 1) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DynamicOrderListScreen(
                            orderType: 'dinein',
                            initialBottomNavItemIndex: 1,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _navItem(
                  context,
                  'Delivery.png',
                  2,
                  notification: _getNotificationCount(2, activeOrdersCount),
                  color: const Color(0xFFFFE26B),
                  onTap: () {
                    debugPrint("Navigating to Delivery orders.");
                    if (selectedIndex != 2) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DynamicOrderListScreen(
                            orderType: 'delivery',
                            initialBottomNavItemIndex: 2,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _navItem(
                  context,
                  'web.png',
                  3,
                  notification: _getNotificationCount(3, activeOrdersCount),
                  color: const Color(0xFFFFE26B),
                  onTap: () {
                    debugPrint("Navigating to Website Orders.");
                    if (selectedIndex != 3) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WebsiteOrdersScreen(
                            initialBottomNavItemIndex: 3,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _navItem(
                  context,
                  'home.png',
                  4,
                  onTap: () {
                    debugPrint("Navigating to Home Screen.");
                    Navigator.pushReplacementNamed(context, '/service-selection');
                  },
                ),
                _navItem(
                  context,
                  'More.png',
                  5,
                  onTap: () {
                    debugPrint("Navigating to Settings Screen.");
                    if (selectedIndex != 5) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(
                            initialBottomNavItemIndex: 5,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );

        if (showDivider) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 1.2,
                color: const Color(0xFFB2B2B2),
              ),
              navBar,
            ],
          );
        }

        return navBar;
      },
    );
  }
}