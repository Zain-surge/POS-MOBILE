// lib/page3.dart

import 'package:epos/page4.dart';
import 'package:epos/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:epos/bottom_nav_item.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';
import 'models/food_item.dart';
import 'package:epos/active_orders_list.dart';
import 'package:provider/provider.dart'; // <--- NEW IMPORT
import 'package:epos/order_counts_provider.dart'; // <--- NEW IMPORT

class Page3 extends StatefulWidget {
  final List<FoodItem> foodItems;

  const Page3({
    super.key,
    required this.foodItems,
  });

  @override
  State<Page3> createState() => _Page3State();
}

class _Page3State extends State<Page3> {
  int _selectedBottomNavItem = 4;

  // REMOVE the local activeOrdersCount map, it will come from the provider
  // Map<String, int> activeOrdersCount = {
  //   'takeaway': 0,
  //   'dinein': 0,
  //   'delivery': 0,
  //   'website': 0,
  // };

  // REMOVE the updateOrderCounts method, ActiveOrdersList will update the provider directly
  // void updateOrderCounts(Map<String, int> newCounts) {
  //   setState(() {
  //     activeOrdersCount = newCounts;
  //   });
  // }

  // Method to get order count for each nav item
  // Now takes the activeOrdersCount map from the provider as a parameter
  String? _getNotificationCount(int index, Map<String, int> currentActiveOrdersCount) {
    int count = 0;
    switch (index) {
      case 0: // Takeaway
        count = currentActiveOrdersCount['takeaway'] ?? 0;
        break;
      case 1: // Dine In
        count = currentActiveOrdersCount['dinein'] ?? 0;
        break;
      case 2: // Delivery
        count = currentActiveOrdersCount['delivery'] ?? 0;
        break;
      case 3: // Website
        count = currentActiveOrdersCount['website'] ?? 0;
        break;
      default:
        return null;
    }
    return count > 0 ? count.toString() : null;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the OrderCountsProvider here
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final activeOrdersCount = orderCountsProvider.activeOrdersCount; // Get the live counts from the provider

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded( // <--- Left section (2/3 of the screen) - Service Selection
                    flex: 2,
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // surge logo

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3D9FF),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: Image.asset(
                              'assets/images/sLogo.png',
                              height: 95,
                              width: 350,
                            ),
                          ),
                        ),

                        // Service options
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // SizedBox(width: 20),
                                    _buildServiceOption('Take Away', 'TakeAway.png', 'takeaway', 0),
                                    _buildServiceOption('Dine In', 'DineIn.png', 'dinein', 1),
                                    _buildServiceOption('Delivery', 'Delivery.png', 'delivery', 2),
                                    // SizedBox(width: 20),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: const VerticalDivider(
                      width: 3,
                      thickness: 3,
                      color: const Color(0xFFB2B2B2),
                    ),
                  ),

                  Expanded( // <--- Right section (1/3 of the screen) - Active Orders List
                    flex: 1,
                    child: Container(
                      color: Colors.white,
                      // ActiveOrdersList no longer needs onOrderCountsChanged callback
                      child: const ActiveOrdersList(), // <--- No onOrderCountsChanged
                    ),
                  ),
                ],
              ),
            ),
            // <--- BOTTOM NAVIGATION BAR WITH NOTIFICATION BUBBLES
            Container(
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFB2B2B2),
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 45.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BottomNavItem(
                      image: 'TakeAway.png',
                      index: 0,
                      selectedIndex: _selectedBottomNavItem,
                      notification: _getNotificationCount(0, activeOrdersCount), // Use provider's data
                      color: const Color(0xFFFFE26B),// Yellow color for notification
                      onTap: () {
                        print("Page3: Navigating to Takeaway orders.");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DynamicOrderListScreen(
                              orderType: 'takeaway',
                              initialBottomNavItemIndex: 0,
                              // No need to pass activeOrdersCount here, DynamicOrderListScreen also consumes Provider
                            ),
                          ),
                        );
                      },
                    ),
                    BottomNavItem(
                      image: 'DineIn.png',
                      index: 1,
                      selectedIndex: _selectedBottomNavItem,
                      notification: _getNotificationCount(1, activeOrdersCount), // Use provider's data
                      color: const Color(0xFFFFE26B), // Yellow color for notification
                      onTap: () {
                        print("Page3: Navigating to Dine-In orders.");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DynamicOrderListScreen(
                              orderType: 'dinein',
                              initialBottomNavItemIndex: 1,
                            ),
                          ),
                        );
                      },
                    ),
                    BottomNavItem(
                      image: 'Delivery.png',
                      index: 2,
                      selectedIndex: _selectedBottomNavItem,
                      notification: _getNotificationCount(2, activeOrdersCount), // Use provider's data
                      color: const Color(0xFFFFE26B), // Yellow color for notification
                      onTap: () {
                        print("Page3: Navigating to Delivery orders.");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DynamicOrderListScreen(
                              orderType: 'delivery',
                              initialBottomNavItemIndex: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    BottomNavItem(
                      image: 'web.png',
                      index: 3,
                      selectedIndex: _selectedBottomNavItem,
                      notification: _getNotificationCount(3, activeOrdersCount), // Use provider's data
                      color: const Color(0xFFFFE26B), // Yellow color for notification
                      onTap: () {
                        print("Page3: Navigating to Website Orders.");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WebsiteOrdersScreen(
                              initialBottomNavItemIndex: 3,
                            ),
                          ),
                        );
                      },
                    ),
                    BottomNavItem(
                      image: 'home.png',
                      index: 4,
                      selectedIndex: _selectedBottomNavItem,
                        onTap: () {
                          print("home tapped");
                        }
                    ),
                    BottomNavItem(
                      image: 'More.png',
                      index: 5,
                      selectedIndex: _selectedBottomNavItem,
                      onTap: () {
                        setState(() {
                          _selectedBottomNavItem = 5;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(
                                initialBottomNavItemIndex: 5,
                              ),
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceOption(String title, String imageName, String orderType, int initialBottomNavItemIndex) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          print("Page3: Service option '$title' tapped. Navigating to Page4 with orderType: $orderType.");
          Navigator.pushNamed(
            context,
            '/page4',
            arguments: {
              'initialSelectedServiceImage': imageName,
              'selectedOrderType': orderType,
            },
          );
        },
        child: Column(
          children: [
            Image.asset(
              'assets/images/$imageName',
              width: title.toLowerCase() == 'delivery' ? 210 : 170,
              height: title.toLowerCase() == 'delivery' ? 210 : 170,
              fit: BoxFit.contain,
              color: const Color(0xFF575858),
            ),
            // Align spacing for labels
            SizedBox(height: title.toLowerCase() == 'delivery' ? 0 : 35),

            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 170),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2D9F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}