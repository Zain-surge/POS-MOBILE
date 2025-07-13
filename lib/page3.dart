// lib/page3.dart

import 'package:epos/page4.dart';
import 'package:epos/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:epos/bottom_nav_item.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';
import 'models/food_item.dart';
import 'package:epos/active_orders_list.dart';

class Page3 extends StatefulWidget {
  final List<FoodItem> foodItems;

  const Page3(
      {super.key, required this.foodItems,});

  @override
  State<Page3> createState() => _Page3State();
}

class _Page3State extends State<Page3> {

  int _selectedBottomNavItem = 4;

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
                  Expanded( // <--- Left section (2/3 of the screen)
                    flex: 2,
                    child: Column( // This column holds existing Page3 content
                      children: [
                        // surge logo
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3D9FF),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'surge',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'Poppins',
                              ),
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
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildServiceOption('Take Away', 'TakeAway.png', 'takeaway', 0),
                                    _buildServiceOption('Dine In', 'DineIn.png', 'dinein', 1),
                                    _buildServiceOption('Delivery', 'Delivery.png', 'delivery', 2),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // IMPORTANT: The Bottom Navigation Bar is MOVED OUT of this Column
                      ],
                    ),
                  ),

                  const VerticalDivider( // <--- Divider between sections
                    width: 1,
                    thickness: 0.5,
                    color: Colors.black,
                  ),

                  Expanded( // <--- Right section (1/3 of the screen)
                    flex: 1,
                    child: Container(
                      color: Colors.white,
                      child: const ActiveOrdersList(),
                    ),
                  ),
                ],
              ),
            ),
            // <--- MOVED THE BOTTOM NAVIGATION BAR HERE, OUTSIDE THE ABOVE ROW
            Container(
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF616161),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BottomNavItem(
                    image: 'TakeAway.png',
                    index: 0,
                    selectedIndex: _selectedBottomNavItem,
                    onTap: () {
                      print("Page3: Navigating to Takeaway orders.");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DynamicOrderListScreen(
                            orderType: 'takeaway',
                            initialBottomNavItemIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  BottomNavItem(
                    image: 'DineIn.png',
                    index: 1,
                    selectedIndex: _selectedBottomNavItem,
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
                    },
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
              width: title.toLowerCase() == 'delivery' ? 220 : 190,
              height: title.toLowerCase() == 'delivery' ? 220 : 190,
              fit: BoxFit.contain,
              color: const Color(0xFF616161),
            ),
            // Align spacing for labels
            SizedBox(height: title.toLowerCase() == 'delivery' ? 10 : 30),

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