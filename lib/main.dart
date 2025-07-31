// lib/main.dart

import 'package:flutter/material.dart';
import 'package:epos/page3.dart';
import 'package:epos/page4.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/main_app_wrapper.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:provider/provider.dart';
import 'package:epos/order_counts_provider.dart'; // <--- NEW IMPORT
import 'package:epos/providers/order_provider.dart';

// Define a GlobalKey for ScaffoldMessengerState
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OrderApiService(); // Instantiates the singleton, which calls _initSocket

  runApp(
    MultiProvider(
      providers: [
        // Using OrderCountsProvider instead of OrderProvider
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => OrderCountsProvider()),
      ],
      child: const MainAppWrapper(
        child: MyApp(),
      ),
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
    _fetchMenuItems(); // Only fetch menu items here now
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
      title: 'EPOS',
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
      home: isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
            );
          case '/service-selection':
            return MaterialPageRoute(
              builder: (context) => Page3(foodItems: foodItems ?? []),
            );
          case '/page4':
            final Map<String, String>? args = settings.arguments as Map<String, String>?;

            final String? initialSelectedServiceImage = args?['initialSelectedServiceImage'];
            final String? selectedOrderType = args?['selectedOrderType'];

            if (selectedOrderType == null) {
              print('Error: selectedOrderType is missing for /page4 route.');
              return MaterialPageRoute(builder: (context) => const Text('Error: Order type not provided.'));
            }

            return MaterialPageRoute(
              builder: (context) => Page4(
                initialSelectedServiceImage: initialSelectedServiceImage,
                foodItems: foodItems ?? [],
                selectedOrderType: selectedOrderType,
                // activeOrdersCount is now obtained via Provider in Page4
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildLoadingScreen() {
    // ... (same as before)
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
    ],),
    ),
    );
  }

  Widget _buildHomeScreen() {
    if (error != null) {
      // ... (same as before)
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
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