import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:epos/widgets/animated_tap_button.dart';
import 'package:epos/settings_screen.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';
import 'package:epos/providers/order_counts_provider.dart';

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

  Widget _navItem(
      BuildContext context,
      String image,
      int index, {
        required String typeKey, // New parameter to identify the order type
        required int count, // Direct count parameter
        required Color bubbleColor, // Direct color parameter
        required VoidCallback onTap,
      }) {
    bool isSelected = selectedIndex == index;
    String displayImage = _getDisplayImage(image, isSelected);

    // Only show notification text if count is greater than 0
    final String notificationText = count > 0 ? count.toString() : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedColorButton(
        backgroundColor: isSelected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        onTap: () {
          onItemSelected?.call(index);
          onTap();
        },
        child: Container(
          width: 140, // Fixed width for consistent rectangular background
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
                      color: bubbleColor, // Use the dynamic color
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    child: Text(
                      notificationText, // Use the dynamic notification text
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
        final dominantOrderColors = orderCountsProvider.dominantOrderColors;

        // Get individual counts
        final collectionCount = activeOrdersCount['collection'] ?? 0;
        final combinedDineinCount = orderCountsProvider.combinedDineinCount; // dinein + takeout
        final deliveryCount = activeOrdersCount['delivery'] ?? 0;
        final websiteCount = activeOrdersCount['website'] ?? 0;

        // Get individual colors
        final collectionColor = dominantOrderColors['collection'] ?? const Color(0xFF8cdd69);
        final combinedDineinColor = orderCountsProvider.combinedDineinColor; // highest priority between dinein and takeout
        final deliveryColor = dominantOrderColors['delivery'] ?? const Color(0xFF8cdd69);
        final websiteColor = dominantOrderColors['website'] ?? const Color(0xFF8cdd69);

        print('🎨 NavBar Update: collection=$collectionCount, combinedDinein=$combinedDineinCount, delivery=$deliveryCount, website=$websiteCount');
        print('🎨 NavBar Colors: collection=${_colorToString(collectionColor)}, combinedDinein=${_colorToString(combinedDineinColor)}, delivery=${_colorToString(deliveryColor)}, website=${_colorToString(websiteColor)}');

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
                  typeKey: 'collection',
                  count: collectionCount,
                  bubbleColor: collectionColor,
                  onTap: () {
                    if (selectedIndex != 0) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DynamicOrderListScreen(
                            orderType: 'collection',
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
                  typeKey: 'dinein',
                  count: combinedDineinCount, // Show combined count of dinein + takeout
                  bubbleColor: combinedDineinColor, // Show highest priority color
                  onTap: () {
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
                  typeKey: 'delivery',
                  count: deliveryCount,
                  bubbleColor: deliveryColor,
                  onTap: () {
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
                  typeKey: 'website',
                  count: websiteCount,
                  bubbleColor: websiteColor,
                  onTap: () {
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
                  typeKey: 'home',
                  count: 0, // No count for home
                  bubbleColor: const Color(0xFF8cdd69), // Default color
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/service-selection');
                  },
                ),
                _navItem(
                  context,
                  'More.png',
                  5,
                  typeKey: 'more',
                  count: 0, // No count for more
                  bubbleColor: const Color(0xFF8cdd69), // Default color
                  onTap: () {
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

  String _colorToString(Color color) {
    if (color == const Color(0xFF8cdd69)) return 'GREEN';
    if (color == const Color(0xFFFFE26B)) return 'YELLOW';
    if (color == const Color(0xFFff4848)) return 'RED';
    return 'UNKNOWN';
  }
}