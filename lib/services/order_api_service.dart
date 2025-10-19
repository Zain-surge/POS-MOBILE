// lib/services/order_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../models/order.dart';
import '../models/customer_search_model.dart';
import '../config/brand_info.dart';

class ShopStatusData {
  final bool shopOpen;

  ShopStatusData({required this.shopOpen});

  factory ShopStatusData.fromJson(Map<String, dynamic> json) {
    return ShopStatusData(shopOpen: json['shop_open'] ?? false);
  }
}

class OrderApiService {
  static const String _backendBaseUrl = 'https://api.surgechain.co.uk';

  // Singleton instance for OrderApiService
  static final OrderApiService _instance = OrderApiService._internal();
  factory OrderApiService() {
    return _instance;
  }
  OrderApiService._internal() {
    _initSocket();
  }

  late IO.Socket _socket;

  // StreamControllers to expose events to the UI
  final _newOrderController = StreamController<Order>.broadcast();
  final _offersUpdatedController = StreamController<List<dynamic>>.broadcast();
  final _shopStatusUpdatedController =
      StreamController<ShopStatusData>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _acceptedOrderController = StreamController<Order>.broadcast();
  final _orderStatusOrDriverChangedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for the streams
  Stream<Order> get newOrderStream => _newOrderController.stream;
  Stream<List<dynamic>> get offersUpdatedStream =>
      _offersUpdatedController.stream;
  Stream<ShopStatusData> get shopStatusUpdatedStream =>
      _shopStatusUpdatedController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Order> get acceptedOrderStream => _acceptedOrderController.stream;
  Stream<Map<String, dynamic>> get orderStatusOrDriverChangedStream =>
      _orderStatusOrDriverChangedController.stream;

  //Method to add an order to the accepted stream
  void addAcceptedOrder(Order order) {
    _acceptedOrderController.add(order);
  }

  void _initSocket() {
    // Socket.IO connects directly, no proxy needed
    // For socket connections, we can add brand info in extraHeaders
    _socket = IO.io(
      _backendBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNewConnection()
          .enableAutoConnect()
          .setExtraHeaders({
            'withCredentials': 'true',
            'brand': BrandInfo.currentBrand,
          })
          .build(),
    );

    _socket.onConnect((_) {
      print('🟢 Connected to backend socket: ${_socket.id}');
      print('🏷️  Brand: ${BrandInfo.currentBrand}');
      _connectionStatusController.add(true);
    });

    _socket.on('new_order', (data) {
      print('📦 New order received from server: $data');
      try {
        // Check if the order is for the current brand before processing
        final currentBrand = BrandInfo.currentBrand.toLowerCase();
        final orderBrand =
            (data['brand_name']?.toString().toLowerCase()) ??
            (data['order_brand']?.toString().toLowerCase()) ??
            '';

        print(
          '🏷️  Order brand: "$orderBrand", Current brand: "$currentBrand"',
        );

        // Only process orders for the current brand
        if (orderBrand.isEmpty || orderBrand == currentBrand) {
          final orderData = Order.fromJson(data);
          print('✅ New order ${orderData.orderId} accepted for current brand');
          _newOrderController.add(orderData);
        } else {
          print(
            '❌ New order rejected - not for current brand (order: "$orderBrand", current: "$currentBrand")',
          );
        }
      } catch (e) {
        print('Error parsing new_order data: $e');
      }
    });

    _socket.on('offers_updated', (data) {
      print('🔥 Real-time offers update received: $data');
      if (data is List) {
        _offersUpdatedController.add(data);
      }
    });

    _socket.on('shop_status_updated', (data) {
      print('🟢 Shop status changed: $data');
      try {
        final shopStatus = ShopStatusData.fromJson(data);
        _shopStatusUpdatedController.add(shopStatus);
      } catch (e) {
        print('Error parsing shop_status_updated data: $e');
      }
    });

    _socket.on("order_status_or_driver_changed", (data) {
      print("🔄 Socket: Order status or driver updated (Real-time): $data");
      print("🔍 Data type: ${data.runtimeType}");

      if (data is Map<String, dynamic>) {
        print("📋 Available keys: ${data.keys.toList()}");
        print("📋 Values: ${data.values.toList()}");

        // Check if the order status change is for the current brand
        final currentBrand = BrandInfo.currentBrand.toLowerCase();
        final orderBrand =
            (data['brand_name']?.toString().toLowerCase()) ??
            (data['order_brand']?.toString().toLowerCase()) ??
            '';

        print(
          '🏷️  Order status change - Order brand: "$orderBrand", Current brand: "$currentBrand"',
        );

        // Only process status changes for the current brand
        if (orderBrand.isEmpty || orderBrand == currentBrand) {
          print('✅ Order status change accepted for current brand');
          _orderStatusOrDriverChangedController.add(data);
        } else {
          print(
            '❌ Order status change rejected - not for current brand (order: "$orderBrand", current: "$currentBrand")',
          );
        }
      } else {
        print(
          '❌ Received non-Map data for order_status_or_driver_changed: $data',
        );
        print('❌ Actual type: ${data.runtimeType}');
      }
    });

    _socket.onDisconnect((_) {
      print('🔴 Disconnected from socket');
      _connectionStatusController.add(false);
    });

    _socket.onError((error) {
      print('❌ Socket Error: $error');
      _connectionStatusController.add(false);
    });

    _socket.onConnectError((err) => print('Connect Error: $err'));
    _socket.onReconnectError((err) => print('Reconnect Error: $err'));
    _socket.onReconnectAttempt((_) => print('Reconnect Attempting...'));
    _socket.onReconnect((attempt) => print('Reconnected on attempt: $attempt'));
    _socket.onReconnectFailed((_) => print('Reconnect Failed'));
  }

  void connectSocket() {
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  void disconnectSocket() {
    _socket.disconnect();
  }

  void dispose() {
    _newOrderController.close();
    _offersUpdatedController.close();
    _shopStatusUpdatedController.close();
    _connectionStatusController.close();
    _acceptedOrderController.close();
    _orderStatusOrDriverChangedController.close();
    _socket.dispose();
  }

  static Uri _buildProxyUrl(String path) {
    return Uri.parse('$_backendBaseUrl$path');
  }

  static Future<List<Order>> fetchTodayOrders() async {
    final url = _buildProxyUrl('/orders/today');
    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(), // Using brand headers
      );
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        List<Order> orders = [];
        for (var orderJson in jsonResponse) {
          orders.add(Order.fromJson(orderJson));
        }
        return orders;
      } else {
        throw Exception(
          'Failed to load today\'s orders: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching today\'s orders: $e');
    }
  }

  // Update order status
  static Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    final url = _buildProxyUrl('/orders/update-status');

    // Map internal status names to backend color codes
    String statusToSend;
    switch (newStatus.toLowerCase()) {
      case 'pending':
        statusToSend = 'yellow';
        break;
      case 'ready':
      case 'on its way':
      case 'preparing':
        statusToSend = 'green';
        break;
      case 'completed':
      case 'delivered':
        statusToSend = 'blue';
        break;
      default:
        statusToSend = newStatus.toLowerCase();
        break;
    }

    final requestBody = {
      'order_id': orderId,
      'status': statusToSend,
      'driver_id': null,
    };

    print('🔍 OrderApiService: Updating order status');
    print('🔍 URL: $url');
    print('🔍 Headers: ${BrandInfo.getDefaultHeaders()}');
    print('🔍 Request Body: ${jsonEncode(requestBody)}');
    print(
      '🔍 Order ID: $orderId, Internal Status: $newStatus, Backend Status: $statusToSend',
    );

    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(), // Using brand headers
        body: jsonEncode(requestBody),
      );

      print('🔍 Response Status Code: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Order status update successful');
        return true;
      } else {
        print(
          '❌ Order status update failed - Status Code: ${response.statusCode}',
        );
        print('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Order status update exception: $e');
      return false;
    }
  }

  // Customer search method
  static Future<CustomerSearchResponse?> searchCustomerByPhoneNumber(
    String phoneNumber,
  ) async {
    String cleanedPhoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final url = _buildProxyUrl('/orders/search-customer');

    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(), // Using brand headers
        body: jsonEncode(<String, dynamic>{'phone_number': cleanedPhoneNumber}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.isNotEmpty) {
          return CustomerSearchResponse.fromJson(responseData);
        } else {
          return null;
        }
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
