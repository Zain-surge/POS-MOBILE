// lib/page3.dart

import 'package:flutter/material.dart';
import 'models/food_item.dart';
import 'package:epos/active_orders_list.dart';
import 'package:epos/custom_bottom_nav_bar.dart';


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

  // Method to handle bottom nav item selection
  void _onBottomNavItemSelected(int index) {
    setState(() {
      _selectedBottomNavItem = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                            padding: const EdgeInsets.symmetric(horizontal: 75),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildServiceOption('Collection', 'TakeAway.png', 'takeaway', 0),
                                    _buildServiceOption('Dine In', 'DineIn.png', 'dinein', 1),
                                    _buildServiceOption('Delivery', 'Delivery.png', 'delivery', 2),
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
                      child: const ActiveOrdersList(),
                    ),
                  ),
                ],
              ),
            ),
            // <--- CUSTOM BOTTOM NAVIGATION BAR
            CustomBottomNavBar(
              selectedIndex: _selectedBottomNavItem,
              onItemSelected: _onBottomNavItemSelected,
              showDivider: true, // Set to true if you want the top divider
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
              width: title.toLowerCase() == 'delivery' ? 225 : 170,
              height: title.toLowerCase() == 'delivery' ? 225 : 170,
              fit: BoxFit.contain,
              color: const Color(0xFF575858),
            ),
            // Align spacing for labels
            SizedBox(height: title.toLowerCase() == 'delivery' ? 0 : 50),

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