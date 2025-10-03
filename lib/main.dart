// lib/main.dart

import 'package:epos/paidpouts_page.dart';
import 'package:flutter/material.dart';
import 'package:epos/page3.dart';
import 'package:epos/page4.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/main_app_wrapper.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'package:epos/providers/website_orders_provider.dart';
import 'package:epos/providers/epos_orders_provider.dart';
import 'package:epos/providers/active_orders_provider.dart';
import 'package:epos/providers/food_item_details_provider.dart';
import 'package:epos/providers/page4_state_provider.dart';
import 'package:epos/providers/sales_report_provider.dart';
import 'package:epos/providers/paidout_provider.dart';
import 'package:epos/sales_report_screen.dart';
import 'package:epos/providers/item_availability_provider.dart';
import 'package:epos/providers/offline_provider.dart';
import 'package:epos/services/uk_time_service.dart';
import 'package:epos/services/offline_storage_service.dart';
import 'package:epos/services/connectivity_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline storage first
  await OfflineStorageService.initialize();

  // Initialize connectivity service
  await ConnectivityService().initialize();

  UKTimeService.debugTime();
  OrderApiService();

  runApp(
    MultiProvider(
      providers: [
        // STEP 1: OrderCountsProvider - BASE PROVIDER
        ChangeNotifierProvider<OrderCountsProvider>(
          create: (_) {
            print('🟢 CREATING OrderCountsProvider');
            return OrderCountsProvider();
          },
          // CRITICAL FIX: Prevent unnecessary rebuilds
          lazy: false,
        ),

        // STEP 2: ActiveOrdersProvider - DEPENDS ON OrderCountsProvider
        ChangeNotifierProxyProvider<OrderCountsProvider, ActiveOrdersProvider>(
          create: (context) {
            print('🟢 CREATING ActiveOrdersProvider');
            final orderCountsProvider = Provider.of<OrderCountsProvider>(
              context,
              listen: false,
            );
            final activeProvider = ActiveOrdersProvider(orderCountsProvider);
            print(
              '🟢 ActiveOrdersProvider CREATED: ${activeProvider.hashCode}',
            );
            return activeProvider;
          },
          update: (context, orderCountsProvider, activeOrdersProvider) {
            print('🟡 ActiveOrdersProvider UPDATE triggered');

            // CRITICAL FIX: Always return existing provider if it exists
            if (activeOrdersProvider != null) {
              print(
                '🟡 REUSING existing ActiveOrdersProvider: ${activeOrdersProvider.hashCode}',
              );
              print('🟡 Skipping update to prevent state loss');
              return activeOrdersProvider;
            }

            // Only create new if absolutely necessary
            print('🟡 Creating NEW ActiveOrdersProvider in update (fallback)');
            final newProvider = ActiveOrdersProvider(orderCountsProvider);
            print(
              '🟢 NEW ActiveOrdersProvider CREATED: ${newProvider.hashCode}',
            );
            return newProvider;
          },
          // CRITICAL FIX: Make non-lazy and prevent unnecessary updates
          lazy: false,
        ),

        // STEP 3: EposOrdersProvider - DEPENDS ON ActiveOrdersProvider
        ChangeNotifierProxyProvider<ActiveOrdersProvider, EposOrdersProvider>(
          create: (context) {
            print('🔵 CREATING EposOrdersProvider');
            final activeOrdersProvider = Provider.of<ActiveOrdersProvider>(
              context,
              listen: false,
            );
            print(
              '🔵 Got ActiveOrdersProvider: ${activeOrdersProvider.hashCode}',
            );

            final eposProvider = EposOrdersProvider();

            print('🔗 LINKING EposOrdersProvider to ActiveOrdersProvider');
            eposProvider.setActiveOrdersProvider(activeOrdersProvider);
            print('✅ LINKING SUCCESSFUL!');

            return eposProvider;
          },
          update: (context, activeOrdersProvider, eposOrdersProvider) {
            print('🔵 EposOrdersProvider UPDATE triggered');

            // CRITICAL FIX: Always return existing provider if it exists
            if (eposOrdersProvider != null) {
              print('🔵 REUSING existing EposOrdersProvider');

              // Re-link if needed but don't recreate
              print('🔗 RE-LINKING existing EposOrdersProvider (silent)');
              eposOrdersProvider.setActiveOrdersProvider(activeOrdersProvider);

              print('🔵 Skipping update to prevent state loss');
              return eposOrdersProvider;
            }

            // Only create new if absolutely necessary
            print('🔵 Creating NEW EposOrdersProvider in update (fallback)');
            final newEposProvider = EposOrdersProvider();
            newEposProvider.setActiveOrdersProvider(activeOrdersProvider);
            print('✅ NEW EposOrdersProvider LINKED!');
            return newEposProvider;
          },
          // CRITICAL FIX: Make non-lazy
          lazy: false,
        ),

        // Other providers - INDEPENDENT
        ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(),
          lazy: false, // CRITICAL FIX: Make non-lazy
        ),
        ChangeNotifierProvider<FoodItemDetailsProvider>(
          create: (_) => FoodItemDetailsProvider(),
          lazy: false, // CRITICAL FIX: Make non-lazy
        ),

        // ADD THIS: Page4StateProvider - NEW PROVIDER FOR STATE PERSISTENCE
        ChangeNotifierProvider<Page4StateProvider>(
          create: (_) {
            print('🟣 CREATING Page4StateProvider');
            return Page4StateProvider();
          },
          lazy: false, // Make non-lazy to ensure state is available immediately
        ),

        // NEW: SalesReportProvider - INDEPENDENT PROVIDER FOR SALES REPORTS
        ChangeNotifierProvider<SalesReportProvider>(
          create: (_) {
            print('📊 CREATING SalesReportProvider');
            return SalesReportProvider();
          },
          lazy: false, // Make non-lazy to ensure immediate availability
        ),

        // NEW: PaidOutProvider - INDEPENDENT PROVIDER FOR PAID OUTS
        ChangeNotifierProvider<PaidOutProvider>(
          create: (_) {
            print('💰 CREATING PaidOutProvider');
            return PaidOutProvider();
          },
          lazy: false, // Make non-lazy to ensure immediate availability
        ),

        ChangeNotifierProvider.value(
          value:
              ItemAvailabilityProvider(), // This ensures same instance everywhere
        ),

        // NEW: OfflineProvider - HANDLES OFFLINE FUNCTIONALITY
        ChangeNotifierProvider<OfflineProvider>(
          create: (_) {
            print('🔄 CREATING OfflineProvider');
            return OfflineProvider();
          },
          lazy: false, // Make non-lazy to ensure immediate availability
        ),
      ],
      child: const MainAppWrapper(child: MyApp()),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<FoodItem>? foodItems;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  Future<void> _fetchMenuItems() async {
    try {
      print(' Fetching menu items at app startup...');
      final items = await ApiService.fetchMenuItems();
      print('✅ Menu items fetched successfully: ${items.length} items');

      setState(() {
        foodItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching menu items: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Village POS',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Poppins'),
          displayMedium: TextStyle(fontFamily: 'Poppins'),
          displaySmall: TextStyle(fontFamily: 'Poppins'),
          headlineLarge: TextStyle(fontFamily: 'Poppins'),
          headlineMedium: TextStyle(fontFamily: 'Poppins'),
          headlineSmall: TextStyle(fontFamily: 'Poppins'),
          titleLarge: TextStyle(fontFamily: 'Poppins'),
          titleMedium: TextStyle(fontFamily: 'Poppins'),
          titleSmall: TextStyle(fontFamily: 'Poppins'),
          bodyLarge: TextStyle(fontFamily: 'Poppins'),
          bodyMedium: TextStyle(fontFamily: 'Poppins'),
          bodySmall: TextStyle(fontFamily: 'Poppins'),
          labelLarge: TextStyle(fontFamily: 'Poppins'),
          labelMedium: TextStyle(fontFamily: 'Poppins'),
          labelSmall: TextStyle(fontFamily: 'Poppins'),
        ),
      ),
      home: MainAppWrapper(
        child: isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder:
                  (context) => MainAppWrapper(
                    child:
                        isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
                  ),
            );
          case '/service-selection':
            return MaterialPageRoute(
              builder:
                  (context) =>
                      MainAppWrapper(child: Page3(foodItems: foodItems ?? [])),
            );
          case '/page4':
            final Map<String, String>? args =
                settings.arguments as Map<String, String>?;

            final String? initialSelectedServiceImage =
                args?['initialSelectedServiceImage'];
            final String? selectedOrderType = args?['selectedOrderType'];

            if (selectedOrderType == null) {
              print('Error: selectedOrderType is missing for /page4 route.');
              return MaterialPageRoute(
                builder:
                    (context) => const Scaffold(
                      body: Center(
                        child: Text('Error: Order type not provided.'),
                      ),
                    ),
              );
            }

            return MaterialPageRoute(
              builder:
                  (context) => MainAppWrapper(
                    child: Page4(
                      initialSelectedServiceImage: initialSelectedServiceImage,
                      foodItems: foodItems ?? [],
                      selectedOrderType: selectedOrderType,
                      // activeOrdersCount is now obtained via Provider in Page4
                    ),
                  ),
            );

          // NEW: Sales Report Route
          case '/sales-report':
            return MaterialPageRoute(
              builder:
                  (context) => const MainAppWrapper(child: SalesReportScreen()),
            );

          // NEW: Paid Outs Route
          case '/paidouts':
            return MaterialPageRoute(
              builder: (context) => const MainAppWrapper(child: PaidOutsPage()),
            );

          default:
            return MaterialPageRoute(
              builder:
                  (context) => MainAppWrapper(
                    child:
                        isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
                  ),
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6CE6)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    error = null;
                  });
                  _fetchMenuItems();
                },
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Failed to load menu items',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    error = null;
                  });
                  _fetchMenuItems();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Page3(foodItems: foodItems ?? []);
  }
}
