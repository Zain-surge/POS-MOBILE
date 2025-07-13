// lib/services/order_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async'; // Required for StreamController

import '../models/order.dart'; // Ensure your Order model is correctly defined here

// Define the structure for shop status data, if not already in models
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
  // Base URL for HTTP requests (using the new thingproxy)
  // IMPORTANT: The backend URL should be appended AFTER the proxy URL,
  // as the proxy itself takes the target URL as part of its path.
  static const String _httpProxyUrl = 'https://thingproxy.freeboard.io/fetch/';
  static const String _backendBaseUrl = 'https://thevillage-backend.onrender.com';

  // Singleton instance for OrderApiService
  static final OrderApiService _instance = OrderApiService._internal();
  factory OrderApiService() {
    return _instance;
  }
  OrderApiService._internal() {
    _initSocket(); // Initialize socket when the singleton is created
  }

  late IO.Socket _socket;

  // StreamControllers to expose events to the UI
  final _newOrderController = StreamController<Order>.broadcast();
  final _offersUpdatedController = StreamController<List<dynamic>>.broadcast(); // Adjust type as needed
  final _shopStatusUpdatedController = StreamController<ShopStatusData>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // NEW: StreamController for orders that have been explicitly 'accepted'
  final _acceptedOrderController = StreamController<Order>.broadcast();

  // Getters for the streams
  Stream<Order> get newOrderStream => _newOrderController.stream;
  Stream<List<dynamic>> get offersUpdatedStream => _offersUpdatedController.stream;
  Stream<ShopStatusData> get shopStatusUpdatedStream => _shopStatusUpdatedController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  // NEW: Getter for the accepted orders stream
  Stream<Order> get acceptedOrderStream => _acceptedOrderController.stream;

  // NEW: Method to add an order to the accepted stream
  void addAcceptedOrder(Order order) {
    _acceptedOrderController.add(order);
    print('OrderApiService: Order ${order.orderId} added to accepted stream.');
  }

  void _initSocket() {
    // Socket.IO typically connects directly, no proxy needed here
    _socket = IO.io(
      _backendBaseUrl, // Use the direct backend URL for sockets
      IO.OptionBuilder()
          .setTransports(['websocket']) // Use WebSocket
          .enableForceNewConnection() // Important for hot reload/reconnection
          .enableAutoConnect() // Enable auto connection
          .setExtraHeaders({'withCredentials': 'true'}) // Pass credentials if needed
          .build(),
    );

    _socket.onConnect((_) {
      print('🟢 Connected to backend socket: ${_socket.id}');
      _connectionStatusController.add(true);
    });

    _socket.on('new_order', (data) {
      print('📦 New order received from server: $data');
      try {
        final orderData = Order.fromJson(data);
        _newOrderController.add(orderData); // All new orders (EPOS & Website) go here first
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
    _acceptedOrderController.close(); // NEW: Close the new controller
    _socket.dispose();
  }

  // Helper to build the full URL including the proxy
  static Uri _buildProxyUrl(String path) {
    return Uri.parse('$_httpProxyUrl$_backendBaseUrl$path');
  }

  // --- HTTP Methods (now using the new proxy) ---

  static Future<List<Order>> fetchTodayOrders() async {
    final url = _buildProxyUrl('/orders/today'); // Use the helper
    try {
      final response = await http.get(url);

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
    final url = _buildProxyUrl('/orders/update-status'); // Use the helper
    print('DEBUG: Attempting to send update status request to URL: $url');
    print('DEBUG: Sending body: ${jsonEncode(<String, dynamic>{'order_id': orderId, 'status': newStatus})}');

    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'order_id': orderId,
          'status': newStatus,
        }),
      );

      print('DEBUG: Received response for order $orderId, status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully updated order status ${orderId} to ${newStatus}');
        return true;
      } else {
        print('Failed to update order status ${orderId} to ${newStatus}: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }
}