// lib/services/order_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../models/order.dart';
import '../models/customer_search_model.dart';
import '../config/brand_info.dart'; // Import the brand configuration

class ShopStatusData {
  final bool shopOpen;

  ShopStatusData({required this.shopOpen});

  factory ShopStatusData.fromJson(Map<String, dynamic> json) {
    return ShopStatusData(
      shopOpen: json['shop_open'] ?? false,
    );
  }
}

class OrderApiService {
  static const String _httpProxyUrl = 'https://corsproxy.io/?';
  static const String _backendBaseUrl = 'https://thevillage-backend.onrender.com';

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
  final _shopStatusUpdatedController = StreamController<ShopStatusData>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _acceptedOrderController = StreamController<Order>.broadcast();
  final _orderStatusOrDriverChangedController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for the streams
  Stream<Order> get newOrderStream => _newOrderController.stream;
  Stream<List<dynamic>> get offersUpdatedStream => _offersUpdatedController.stream;
  Stream<ShopStatusData> get shopStatusUpdatedStream => _shopStatusUpdatedController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Order> get acceptedOrderStream => _acceptedOrderController.stream;
  Stream<Map<String, dynamic>> get orderStatusOrDriverChangedStream => _orderStatusOrDriverChangedController.stream;

  //Method to add an order to the accepted stream
  void addAcceptedOrder(Order order) {
    _acceptedOrderController.add(order);
    print('OrderApiService: Order ${order.orderId} added to accepted stream.');
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
        'brand': BrandInfo.currentBrand, // Adding brand to socket headers
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
        final orderData = Order.fromJson(data);
        _newOrderController.add(orderData);
      } catch (e) {
        print('Error parsing new_order data: $e');
      }
    });

    _socket.on('offers_updated', (data) {
      print('🔥 Real-time offers update received: $data');
      if (data is List) {
        _offersUpdatedController.add(data);
      } else {
        print('Offers data is not a list: $data');
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
        _orderStatusOrDriverChangedController.add(data);
      } else {
        print('❌ Received non-Map data for order_status_or_driver_changed: $data');
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
    return Uri.parse('$_httpProxyUrl$_backendBaseUrl$path');
  }

  static Future<List<Order>> fetchTodayOrders() async {
    final url = _buildProxyUrl('/orders/today');
    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(), // Using brand headers
      );
      print(response.body);

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((orderJson) => Order.fromJson(orderJson)).toList();
      } else {
        throw Exception('Failed to load today\'s orders: ${response.statusCode} ${response.body}');
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
        print('Warning: No color mapping found for status "$newStatus". Sending as is.');
        break;
    }

    print('DEBUG: Attempting to send update status request to URL: $url');
    print('DEBUG: Sending body: ${jsonEncode(<String, dynamic>{
      'order_id': orderId,
      'status': statusToSend,
      'driver_id': null,
    })}');

    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(), // Using brand headers
        body: jsonEncode(<String, dynamic>{
          'order_id': orderId,
          'status': statusToSend,
          'driver_id': null,
        }),
      );

      print('DEBUG: Received response for order $orderId, status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated order status $orderId to $newStatus (sent as $statusToSend)');
        return true;
      } else {
        print('Failed to update order status $orderId to $newStatus (sent as $statusToSend): ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  // Customer search method
  static Future<CustomerSearchResponse?> searchCustomerByPhoneNumber(String phoneNumber) async {
    String cleanedPhoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final url = _buildProxyUrl('/orders/search-customer');

    print('PHONE NUMBER: Attempting to search customer with URL: $url');
    print('PHONE NUMBER: Sending phone number: $cleanedPhoneNumber');

    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(), // Using brand headers
        body: jsonEncode(<String, dynamic>{
          'phone_number': cleanedPhoneNumber,
        }),
      );

      print('DEBUG: Received response for customer search: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.isNotEmpty) {
          return CustomerSearchResponse.fromJson(responseData);
        } else {
          return null;
        }
      } else if (response.statusCode == 404) {
        print('Customer not found for phone number: $cleanedPhoneNumber (Status 404)');
        return null;
      } else {
        print('Failed to search customer. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during customer search: $e');
      return null;
    }
  }
}