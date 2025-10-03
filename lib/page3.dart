// lib/page3.dart

// import 'dart:io';
import 'package:flutter/material.dart';
import 'models/food_item.dart';
import 'package:epos/active_orders_list.dart';
import 'package:epos/custom_bottom_nav_bar.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/services/custom_popup_service.dart';
import 'package:epos/widgets/animated_tap_button.dart';

class Page3 extends StatefulWidget {
  final List<FoodItem> foodItems;

  const Page3({super.key, required this.foodItems});

  @override
  State<Page3> createState() => _Page3State();
}

class _Page3State extends State<Page3> {
  int _selectedBottomNavItem = 4;
  bool _canOpenDrawer = false; // Restored to false by default
  bool _isDrawerOpening = false;

  @override
  void initState() {
    super.initState();
    _checkDrawerAvailability(); // Restored printer check
  }

  // Method to handle bottom nav item selection
  void _onBottomNavItemSelected(int index) {
    setState(() {
      _selectedBottomNavItem = index;
    });
  }

  // Cash drawer methods
  Future<void> _checkDrawerAvailability() async {
    try {
      bool canOpen = await ThermalPrinterService().canOpenDrawer();
      if (mounted) {
        setState(() {
          _canOpenDrawer = canOpen;
        });
      }
    } catch (e) {
      print('Error checking drawer availability: $e');
    }
  }

  Future<void> _openCashDrawer() async {
    if (_isDrawerOpening || !_canOpenDrawer) return;

    setState(() {
      _isDrawerOpening = true;
    });

    try {
      bool success = await ThermalPrinterService().openCashDrawer();

      if (mounted) {
        CustomPopupService.show(
          context,
          success
              ? '💰 Cash drawer opened successfully'
              : '❌ Failed to open cash drawer',
          type: success ? PopupType.success : PopupType.failure,
        );
      }
    } catch (e) {
      print('Error opening cash drawer: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          '❌ Cash drawer error: $e',
          type: PopupType.failure,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDrawerOpening = false;
        });
      }
    }
  }

  void _openPaidOutsPage() {
    Navigator.pushNamed(context, '/paidouts');
  }

  // // Comprehensive USB diagnostics for troubleshooting
  // Future<void> _diagnoseUSBIssues() async {
  //   try {
  //     // Show loading dialog
  //     if (mounted) {
  //       CustomPopupService.show(
  //         context,
  //         '🔍 Running USB diagnostics...',
  //         type: PopupType.success,
  //       );
  //     }

  //     ThermalPrinterService printer = ThermalPrinterService();

  //     // Simple USB connection test first
  //     Map<String, bool> connections = await printer.testAllConnections();

  //     // Build basic diagnostic report
  //     Map<String, dynamic> diagnosis = {
  //       'usb_available': connections['usb'] ?? false,
  //       'bluetooth_available': connections['bluetooth'] ?? false,
  //       'platform_supported':
  //           Platform.isAndroid || Platform.isWindows || Platform.isLinux,
  //     };

  //     // Build diagnostic report
  //     String report = '📊 USB Diagnostic Report:\n\n';

  //     // Platform support
  //     report +=
  //         '🖥️ Platform: ${diagnosis['platform_supported'] ? '✅ Supported' : '❌ Not Supported'}\n';

  //     // USB Connection
  //     report +=
  //         '🔌 USB Printer: ${diagnosis['usb_available'] ? '✅ Detected' : '❌ Not Found'}\n';

  //     // Bluetooth Connection
  //     report +=
  //         '📡 Bluetooth: ${diagnosis['bluetooth_available'] ? '✅ Available' : '❌ Not Available'}\n\n';

  //     // Provide recommendations based on results
  //     if (!diagnosis['usb_available']) {
  //       report += '💡 USB Troubleshooting:\n';
  //       report += '• Ensure USB printer is connected and powered ON\n';
  //       report += '• Check USB cable integrity\n';
  //       report += '• Try a different USB port\n';
  //       report += '• For Android: Enable USB debugging in Developer Options\n';
  //       report += '• For Android: Grant USB permissions when prompted\n';
  //       report += '• Restart the printer and try again\n\n';
  //     }

  //     if (!diagnosis['platform_supported']) {
  //       report += '⚠️ Platform not supported for USB printing\n';
  //       report += '💡 Use Bluetooth printing instead\n\n';
  //     }

  //     if (diagnosis['usb_available']) {
  //       report += '✅ USB printer detected! You should be able to:\n';
  //       report += '• Print receipts via USB\n';
  //       report += '• Open cash drawer (if connected to printer)\n\n';
  //       report += '🖨️ For Xprinter models:\n';
  //       report += '• XP-58, XP-80, XP-365 series are well supported\n';
  //       report += '• Uses ESC/POS commands for printing\n';
  //       report += '• Cash drawer connects to printer RJ11/RJ12 port\n';
  //     }

  //     // Show comprehensive diagnostic results
  //     if (mounted) {
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return AlertDialog(
  //             title: Text('🔍 USB Diagnostic Results'),
  //             content: SingleChildScrollView(
  //               child: Text(
  //                 report,
  //                 style: TextStyle(fontFamily: 'monospace', fontSize: 12),
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: Text('Close'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     }
  //   } catch (e) {
  //     print('Error during USB diagnosis: $e');
  //     if (mounted) {
  //       CustomPopupService.show(
  //         context,
  //         '❌ USB diagnostic failed: $e',
  //         type: PopupType.failure,
  //       );
  //     }
  //   }
  // }

  // // // Test USB printer functionality
  // Future<void> _testUSBPrinter() async {
  //   print('\n🧪 MANUAL USB PRINTER TEST INITIATED');
  //   print('=' * 50);

  //   try {
  //     ThermalPrinterService printer = ThermalPrinterService();

  //     // Test USB connection
  //     print('📡 Testing USB printer connection...');
  //     Map<String, bool> connections = await printer.testAllConnections();

  //     bool usbAvailable = connections['usb'] ?? false;
  //     bool bluetoothAvailable = connections['bluetooth'] ?? false;

  //     print('📊 CONNECTION TEST RESULTS:');
  //     print('   USB: ${usbAvailable ? "✅ AVAILABLE" : "❌ NOT AVAILABLE"}');
  //     print(
  //       '   Bluetooth: ${bluetoothAvailable ? "✅ AVAILABLE" : "❌ NOT AVAILABLE"}',
  //     );

  //     if (usbAvailable) {
  //       print('🖨️ USB printer detected! Attempting test print...');

  //       // Test the actual USB connection
  //       print('🔌 Testing detailed USB connection...');
  //       bool connectionWorking = false;

  //       try {
  //         // The testAllConnections already tested USB, so if we got here it should work
  //         // But let's do a more thorough test by checking the internal USB method
  //         connectionWorking =
  //             true; // Since testAllConnections already confirmed USB works
  //         print('🔌 USB Connection: Ready for printing');
  //       } catch (e) {
  //         print('🔌 USB Connection Error: $e');
  //         connectionWorking = false;
  //       }

  //       bool printSuccess = connectionWorking;

  //       if (printSuccess) {
  //         print('✅ USB CONNECTION TEST SUCCESSFUL!');

  //         // Show detailed success dialog to testing team
  //         if (mounted) {
  //           showDialog(
  //             context: context,
  //             builder: (BuildContext context) {
  //               return AlertDialog(
  //                 backgroundColor: Colors.green[50],
  //                 title: const Row(
  //                   children: [
  //                     Icon(Icons.check_circle, color: Colors.green, size: 30),
  //                     SizedBox(width: 10),
  //                     Text(
  //                       'USB Printer SUCCESS!',
  //                       style: TextStyle(color: Colors.green),
  //                     ),
  //                   ],
  //                 ),
  //                 content: const Column(
  //                   mainAxisSize: MainAxisSize.min,
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text('✅ USB printer detected and connected'),
  //                     Text('✅ Communication established'),
  //                     Text('✅ Printer responding to commands'),
  //                     SizedBox(height: 10),
  //                     Text(
  //                       '🎉 USB PRINTING IS WORKING!',
  //                       style: TextStyle(fontWeight: FontWeight.bold),
  //                     ),
  //                     SizedBox(height: 10),
  //                     Text(
  //                       'The testing team can now use USB printer for receipts.',
  //                     ),
  //                   ],
  //                 ),
  //                 actions: [
  //                   TextButton(
  //                     onPressed: () => Navigator.of(context).pop(),
  //                     child: const Text('OK'),
  //                   ),
  //                 ],
  //               );
  //             },
  //           );
  //         }
  //       } else {
  //         print('❌ USB CONNECTION TEST FAILED');

  //         if (mounted) {
  //           showDialog(
  //             context: context,
  //             builder: (BuildContext context) {
  //               return AlertDialog(
  //                 backgroundColor: Colors.orange[50],
  //                 title: const Row(
  //                   children: [
  //                     Icon(Icons.warning, color: Colors.orange, size: 30),
  //                     SizedBox(width: 10),
  //                     Text(
  //                       'USB Connection Issue',
  //                       style: TextStyle(color: Colors.orange),
  //                     ),
  //                   ],
  //                 ),
  //                 content: const Column(
  //                   mainAxisSize: MainAxisSize.min,
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       '⚠️ USB printer was detected but communication failed',
  //                     ),
  //                     SizedBox(height: 10),
  //                     Text('Possible solutions:'),
  //                     Text('• Check printer drivers are installed'),
  //                     Text('• Try disconnecting and reconnecting'),
  //                     Text('• Ensure printer supports ESC/POS'),
  //                   ],
  //                 ),
  //                 actions: [
  //                   TextButton(
  //                     onPressed: () => Navigator.of(context).pop(),
  //                     child: const Text('OK'),
  //                   ),
  //                 ],
  //               );
  //             },
  //           );
  //         }
  //       }
  //     } else {
  //       print('⚠️ NO USB PRINTER DETECTED');
  //       print('   This could mean:');
  //       print('   • No USB printer is connected');
  //       print('   • Printer is not powered on');
  //       print('   • USB cable issue');
  //       print('   • Printer drivers not installed');

  //       if (mounted) {
  //         showDialog(
  //           context: context,
  //           builder: (BuildContext context) {
  //             return AlertDialog(
  //               backgroundColor: Colors.red[50],
  //               title: const Row(
  //                 children: [
  //                   Icon(Icons.usb_off, color: Colors.red, size: 30),
  //                   SizedBox(width: 10),
  //                   Text(
  //                     'No USB Printer Found',
  //                     style: TextStyle(color: Colors.red),
  //                   ),
  //                 ],
  //               ),
  //               content: const Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text('❌ No USB printer detected'),
  //                   SizedBox(height: 10),
  //                   Text('Please check:'),
  //                   Text('• USB printer is connected'),
  //                   Text('• Printer is powered ON'),
  //                   Text('• USB cable is working'),
  //                   Text('• Try different USB port'),
  //                   SizedBox(height: 10),
  //                   Text(
  //                     'Note: Only thermal printers with USB support will work.',
  //                   ),
  //                 ],
  //               ),
  //               actions: [
  //                 TextButton(
  //                   onPressed: () => Navigator.of(context).pop(),
  //                   child: const Text('OK'),
  //                 ),
  //               ],
  //             );
  //           },
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     print('❌ USB TEST ERROR: $e');

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('❌ USB test error: ${e.toString()}'),
  //           backgroundColor: Colors.red,
  //           duration: const Duration(seconds: 4),
  //         ),
  //       );
  //     }
  //   }

  //   print('=' * 50);
  //   print('🧪 USB PRINTER TEST COMPLETED\n');
  // }

  // Updated positioning to avoid popup overlap and accommodate both buttons
  Widget _buildCashDrawerButton() {
    // Calculate dynamic top position based on whether cash drawer is available
    // If cash drawer is available, position lower to accommodate both buttons
    // If not available, position higher for just the paid outs button
    double topPosition = _canOpenDrawer ? 100.0 : 80.0;

    return Positioned(
      top: topPosition,
      left: 20,
      child: Column(
        children: [
          // USB DIAGNOSTIC BUTTON - For troubleshooting USB printer issues
          // GestureDetector(
          //   onTap: _diagnoseUSBIssues,
          //   child: Container(
          //     width: 170,
          //     height: 45,
          //     margin: const EdgeInsets.only(bottom: 10),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFFE3F2FD), // Light blue for diagnostics
          //       borderRadius: BorderRadius.circular(25),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.black26,
          //           blurRadius: 4,
          //           offset: Offset(0, 2),
          //         ),
          //       ],
          //     ),
          //     child: Center(
          //       child: Text(
          //         '🔍 USB Diagnostics',
          //         style: TextStyle(
          //           color: Colors.blue[800],
          //           fontWeight: FontWeight.bold,
          //           fontSize: 14,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          // // OLD USB TEST BUTTON - For testing USB printer functionality
          // GestureDetector(
          //   onTap: _testUSBPrinter,
          //   child: Container(
          //     width: 170,
          //     height: 55,
          //     margin: const EdgeInsets.only(bottom: 10),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFFFFE4B5), // Light orange color
          //       borderRadius: BorderRadius.circular(30),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.black.withOpacity(0.1),
          //           blurRadius: 8,
          //           offset: const Offset(0, 2),
          //         ),
          //       ],
          //     ),
          //     child: const Center(
          //       child: Text(
          //         '🖨️ Test USB',
          //         style: TextStyle(
          //           fontFamily: 'Poppins',
          //           fontSize: 16,
          //           fontWeight: FontWeight.w600,
          //           color: Color(0xFF5D4037),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          // Cash Drawer Button - Only show if drawer is available
          if (_canOpenDrawer) ...[
            GestureDetector(
              onTap: _isDrawerOpening ? null : _openCashDrawer,
              child: Container(
                width: 170,
                height: 55,
                decoration: BoxDecoration(
                  color:
                      _isDrawerOpening
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFFF2D9F9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      _isDrawerOpening
                          ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF575858),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.point_of_sale,
                                color: const Color(0xFF575858),
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cash Drawer',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF575858),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
            const SizedBox(height: 15), // Increased spacing between buttons
          ],

          // Paid Outs Button - Always visible
          GestureDetector(
            onTap: _openPaidOutsPage,
            child: Container(
              width: 170,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.money_off,
                    color: const Color(0xFF575858),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paid Outs',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF575858),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        // <--- Left section (2/3 of the screen) - Service Selection
                        flex: 2,
                        child: Column(
                          children: [
                            const SizedBox(height: 30),

                            // surge logo
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 5,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 75,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildServiceOption(
                                          'Collection',
                                          'TakeAway.png',
                                          'takeaway',
                                          0,
                                        ),
                                        _buildServiceOption(
                                          'Dine In',
                                          'DineIn.png',
                                          'dinein',
                                          1,
                                        ),
                                        _buildServiceOption(
                                          'Delivery',
                                          'Delivery.png',
                                          'delivery',
                                          2,
                                        ),
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

                      Expanded(
                        // <--- Right section (1/3 of the screen) - Active Orders List
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
          // Always show the buttons container with improved positioning
          _buildCashDrawerButton(),
        ],
      ),
    );
  }

  Widget _buildServiceOption(
    String title,
    String imageName,
    String orderType,
    int initialBottomNavItemIndex,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
            child: AnimatedColorButton(
              backgroundColor: const Color(0xFFF2D9F9),
              borderRadius: BorderRadius.circular(30),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () {
                print(
                  "Page3: Service option '$title' tapped. Navigating to Page4 with orderType: $orderType.",
                );
                Navigator.pushNamed(
                  context,
                  '/page4',
                  arguments: {
                    'initialSelectedServiceImage': imageName,
                    'selectedOrderType': orderType,
                  },
                );
              },
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
    );
  }
}
