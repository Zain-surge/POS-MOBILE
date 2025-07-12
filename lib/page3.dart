// In lib/page3.dart

import 'package:epos/page4.dart';
import 'package:flutter/material.dart';
import 'package:epos/bottom_nav_item.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';
import 'models/food_item.dart';

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

            // Service options (unchanged)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pass 'takeaway' as orderType
                        _buildServiceOption('Take out', 'TakeAway.png', 'takeaway', 0),
                        // Pass 'dinein' as orderType
                        _buildServiceOption('Eat-in', 'DineIn.png', 'dinein', 1),
                        // Pass 'delivery' as orderType
                        _buildServiceOption('Delivery', 'Delivery.png', 'delivery', 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar - NOW USING BottomNavItem
            Container(
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF616161), // Using Color directly for clarity
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
                      print("Page3: More button tapped.");
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

  // Modified _buildServiceOption to pass orderType to Page4
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
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              color: const Color(0xFF616161),
            ),
            const SizedBox(height: 10),
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
                      fontSize: 18,
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