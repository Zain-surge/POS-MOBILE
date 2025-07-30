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

  // Removed _getNotificationCount method.
  // The notification count will be directly accessed within _navItem using the provider's map.

  Widget _navItem(
      BuildContext context,
      String image,
      int index, {
        required String typeKey, // New parameter to identify the order type (e.g., 'takeaway', 'dinein')
        required Map<String, int> activeCounts, // Pass the counts map from provider
        required Map<String, Color> dominantColors, // Pass the colors map from provider
        required VoidCallback onTap,
      }) {
    bool isSelected = selectedIndex == index;
    String displayImage = _getDisplayImage(image, isSelected);

    // Get the notification count and dominant color for this specific item from the maps
    final int count = activeCounts[typeKey] ?? 0;
    // Default to a yellow color if no dominant color is found for the type
    final Color bubbleColor = dominantColors[typeKey] ?? const Color(0xFFFFE26B);

    // Only show notification text if count is greater than 0
    final String notificationText = count > 0 ? count.toString() : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // It seems you're calling onItemSelected and then onTap,
          // if onTap handles the navigation, onItemSelected might be redundant here.
          // Keeping your existing structure.
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
              // Only display the notification bubble if notificationText is not empty
              if (notificationText.isNotEmpty)
                Positioned(
                  top: -2,
                  // Adjust right position based on image
                  right: (displayImage == 'Delivery.png' || displayImage == 'Deliverywhite.png') ? 14 : 30,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bubbleColor, // <--- Use the dynamic color here
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    child: Text(
                      notificationText, // <--- Use the dynamic notification text here
                      style: const TextStyle(
                        color: Colors.black, // Keep text color black for contrast
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
      if (image == 'TakeAway.png') return 'TakeAwaywhite.png';
      if (image == 'DineIn.png') return 'DineInwhite.png';
      if (image == 'Delivery.png') return 'Deliverywhite.png';
      if (image == 'web.png') return 'webwhite.png';
      // Home and More typically don't change color, so return their original assets
      if (image == 'home.png') return 'home.png';
      if (image == 'More.png') return 'More.png';
      // Generic fallback for other images following the "name.png" -> "namewhite.png" pattern
      if (image.contains('.png') && !image.contains('white.png')) {
        return image.replaceAll('.png', 'white.png');
      }
    } else {
      // If not selected, return the non-white version
      if (image == 'TakeAwaywhite.png') return 'TakeAway.png';
      if (image == 'DineInwhite.png') return 'DineIn.png';
      if (image == 'Deliverywhite.png') return 'Delivery.png';
      // Corrected: If the image is currently 'webwhite.png' (selected state),
      // it should return 'web.png' when unselected.
      if (image == 'webwhite.png') return 'web.png';
      if (image == 'home.png') return 'home.png';
      if (image == 'More.png') return 'More.png';
      // Generic fallback for other images following the "namewhite.png" -> "name.png" pattern
      if (image.contains('white.png')) {
        return image.replaceAll('white.png', '.png');
      }
    }
    return image; // Return original if no specific rule applies
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderCountsProvider>(
      builder: (context, orderCountsProvider, child) {
        final activeOrdersCount = orderCountsProvider.activeOrdersCount;
        // Retrieve the dominant colors map from the provider
        final dominantOrderColors = orderCountsProvider.dominantOrderColors;

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
                  typeKey: 'takeaway', // Pass the type key
                  activeCounts: activeOrdersCount, // Pass the counts map
                  dominantColors: dominantOrderColors, // Pass the colors map
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
                  typeKey: 'dinein', // Pass the type key
                  activeCounts: activeOrdersCount, // Pass the counts map
                  dominantColors: dominantOrderColors, // Pass the colors map
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
                  typeKey: 'delivery', // Pass the type key
                  activeCounts: activeOrdersCount, // Pass the counts map
                  dominantColors: dominantOrderColors, // Pass the colors map
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
                  typeKey: 'website', // Pass the type key
                  activeCounts: activeOrdersCount, // Pass the counts map
                  dominantColors: dominantOrderColors, // Pass the colors map
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
                  typeKey: 'home', // No count/color expected for 'home', but pass maps anyway
                  activeCounts: activeOrdersCount,
                  dominantColors: dominantOrderColors,
                  onTap: () {
                    debugPrint("Navigating to Home Screen.");
                    Navigator.pushReplacementNamed(context, '/service-selection');
                  },
                ),
                _navItem(
                  context,
                  'More.png',
                  5,
                  typeKey: 'more', // No count/color expected for 'more', but pass maps anyway
                  activeCounts: activeOrdersCount,
                  dominantColors: dominantOrderColors,
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