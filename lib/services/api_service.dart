import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../config/brand_info.dart';
import '../models/paidout_models.dart';

class ApiService {
  static const String _apiBase = "https://api.thevillagepizzeria.uk";

  // Helper method to build full URLs
  static String _buildUrl(String path) {
    return '$_apiBase$path';
  }

  // Method to mark order as paid
  static Future<bool> markOrderAsPaid(
    int orderId, {
    String? paymentType,
    bool paidStatus = true,
  }) async {
    final url = Uri.parse(_buildUrl('/item/set-paid-status'));
    try {
      final Map<String, dynamic> requestBody = {
        'order_id': orderId,
        'paid_status': paidStatus,
      };

      // Add payment type if provided
      if (paymentType != null) {
        requestBody['payment_type'] = paymentType;
      }

      print("💳 markOrderAsPaid: Sending ${jsonEncode(requestBody)}");

      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(requestBody),
      );
      print("markOrderAsPaid: Response Code: ${response.statusCode}");
      print("markOrderAsPaid: Response: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Order $orderId marked as paid successfully");
        return true;
      } else {
        print(
          "❌ Failed to mark order as paid: ${response.statusCode} - ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("❌ Error marking order as paid: $e");
      return false;
    }
  }

  // Method to send payment link to customer
  static Future<Map<String, dynamic>> sendPaymentLink({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required List<Map<String, dynamic>> cartItems,
    required double totalPrice,
  }) async {
    final url = Uri.parse(_buildUrl('/payment/send-payment-link'));
    try {
      final requestBody = {
        'customerInfo': {
          'name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
        'cartItems': cartItems,
        'totalPrice': totalPrice,
      };

      print("sendPaymentLink: Sending request to ${url.toString()}");
      print("sendPaymentLink: Request body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(requestBody),
      );

      print("sendPaymentLink: Response Code: ${response.statusCode}");
      print("sendPaymentLink: Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'error': 'Failed to send payment link: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      print("sendPaymentLink: Error: $e");
      return {'success': false, 'error': 'Error sending payment link: $e'};
    }
  }

  static Future<List<FoodItem>> fetchMenuItems() async {
    final url = Uri.parse(_buildUrl('/item/items'));
    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("fetchMenuItems: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => FoodItem.fromJson(json)).toList();
      } else {
        throw Exception(
          "Failed to load menu items: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("fetchMenuItems: Error fetching items: $e");
      throw Exception("Error fetching menu items: $e");
    }
  }

  static Future<OrderCreationResponse> createOrderFromMap(
    Map<String, dynamic> orderData,
  ) async {
    final url = Uri.parse(_buildUrl('/orders/full-create'));
    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(orderData),
      );

      print(
        "Order body length: ${utf8.encode(jsonEncode(orderData)).length} bytes",
      );
      print("dY\x0f DEBUG: Response status: ${response.statusCode}");
      print("dY\x0f DEBUG: Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data.containsKey('error')) {
          print("Backend Error: ${data['error']}");
        }

        final orderResponse = OrderCreationResponse(
          orderId: data['order_id']?.toString(),
          orderNumber: data['order_number']?.toString(),
        );

        if (orderResponse.orderId != null) {
          print(
            "dY\x0f DEBUG: Successfully created order with ID: ${orderResponse.orderId}",
          );
        } else {
          print(
            'createOrderFromMap: Warning: Backend response does not contain "order_id" key. Body: ${response.body}',
          );
        }

        if (orderResponse.orderNumber == null) {
          print(
            'createOrderFromMap: Warning: Backend response does not contain "order_number" key.',
          );
        }

        return orderResponse;
      } else {
        throw Exception(
          "Failed to create order from map: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print('createOrderFromMap: CRITICAL ERROR during API call: $e');
      throw Exception(
        'Failed to connect to the server or process request for order creation: $e',
      );
    }
  }

  static Future<void> submitPaidOuts(List<PaidOut> paidOuts) async {
    final url = Uri.parse(_buildUrl('/admin/paidouts'));

    print("submitPaidOuts: Attempting to submit ${paidOuts.length} paid outs");

    final requestBody = {
      "paidouts": paidOuts.map((paidOut) => paidOut.toJson()).toList(),
    };

    print("submitPaidOuts: Request body: ${jsonEncode(requestBody)}");

    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(requestBody),
      );

      print("submitPaidOuts: Response Code: ${response.statusCode}");
      print("submitPaidOuts: Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("submitPaidOuts: Successfully submitted paid outs");
      } else {
        throw Exception(
          "Failed to submit paid outs: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("submitPaidOuts: Error submitting paid outs: $e");
      throw Exception("Error submitting paid outs: $e");
    }
  }

  static Future<List<PaidOutRecord>> getTodaysPaidOuts() async {
    final url = Uri.parse(_buildUrl('/admin/paidouts/today'));
    print("getTodaysPaidOuts: Attempting to fetch from URL: $url");
    print("getTodaysPaidOuts: Using headers: ${BrandInfo.getDefaultHeaders()}");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getTodaysPaidOuts: Response Code: ${response.statusCode}");
      print("getTodaysPaidOuts: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print("getTodaysPaidOuts: Successfully parsed ${data.length} records");
        return data.map((json) => PaidOutRecord.fromJson(json)).toList();
      } else {
        throw Exception(
          "getTodaysPaidOuts: Failed with status ${response.statusCode}",
        );
      }
    } catch (e) {
      print("getTodaysPaidOuts: Error: $e");
      throw Exception("Error fetching today's paid outs: $e");
    }
  }

  static Future<Map<String, dynamic>> getShopStatus() async {
    final url = Uri.parse(_buildUrl('/admin/shop-status'));
    print("getShopStatus: Attempting to fetch from URL: $url");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getShopStatus: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          "Failed to load shop status: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("getShopStatus: Error fetching shop status: $e");
      throw Exception("Error fetching shop status: $e");
    }
  }

  static Future<String> toggleShopStatus(bool shopOpen) async {
    final url = Uri.parse(_buildUrl('/admin/shop-toggle'));
    print("toggleShopStatus: Attempting to toggle shop status to: $shopOpen");

    try {
      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({"shop_open": shopOpen}),
      );

      print("toggleShopStatus: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop status updated successfully';
      } else {
        throw Exception(
          "Failed to toggle shop status: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("toggleShopStatus: Error: $e");
      throw Exception("Error updating shop status: $e");
    }
  }

  static Future<String> updateShopTimings(
    String openTime,
    String closeTime,
  ) async {
    final url = Uri.parse(_buildUrl('/admin/update-shop-timings'));
    print(
      "updateShopTimings: Attempting to update shop timings - Open: $openTime, Close: $closeTime",
    );

    try {
      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({
          "shop_open_time": openTime,
          "shop_close_time": closeTime,
        }),
      );

      print("updateShopTimings: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop timings updated successfully';
      } else {
        throw Exception(
          "Failed to update shop timings: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("updateShopTimings: Error: $e");
      throw Exception("Error updating shop timings: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getOffers() async {
    final url = Uri.parse(_buildUrl('/admin/offers'));
    print("getOffers: Attempting to fetch from URL: $url");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getOffers: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          "Failed to load offers: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("getOffers: Error fetching offers: $e");
      throw Exception("Error fetching offers: $e");
    }
  }

  static Future<Map<String, dynamic>> updateOfferStatus(
    String offerText,
    bool value,
  ) async {
    final url = Uri.parse(_buildUrl('/admin/offers/update'));
    print(
      "updateOfferStatus: Attempting to update offer: $offerText to value: $value",
    );

    try {
      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({"offer_text": offerText, "value": value}),
      );

      print("updateOfferStatus: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          "Failed to update offer status: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("updateOfferStatus: Error: $e");
      throw Exception("Error updating offer status: $e");
    }
  }

  static Future<FoodItem> setItemAvailability(
    int itemId,
    bool availability,
  ) async {
    final url = Uri.parse(_buildUrl('/item/set-availability'));
    print(
      "setItemAvailability: Attempting to update item availability for ID: $itemId to $availability",
    );

    try {
      final response = await http
          .put(
            url,
            headers: BrandInfo.getDefaultHeaders(),
            body: jsonEncode({'item_id': itemId, 'availability': availability}),
          )
          .timeout(const Duration(seconds: 10));

      print("setItemAvailability: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData.containsKey('item')) {
          return FoodItem.fromJson(responseData['item']);
        } else {
          throw Exception(
            'Failed to set item availability: "item" key missing in response.',
          );
        }
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? 'Unknown error';
        } catch (parseError) {
          print(
            "setItemAvailability: Failed to parse error response: $parseError",
          );
          errorMessage =
              response.body.isNotEmpty ? response.body : 'Network error';
        }
        throw Exception(
          'Failed to set item availability: ${response.statusCode} - $errorMessage',
        );
      }
    } catch (e) {
      print("setItemAvailability: Error: $e");
      throw Exception("Error updating item availability: $e");
    }
  }

  static Future<Map<String, dynamic>> getTodaysReport({
    String? source,
    String? payment,
    String? orderType,
  }) async {
    final Map<String, String> queryParams = {};

    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri url = Uri.parse(
      _buildUrl('/admin/sales-report/today'),
    ).replace(queryParameters: queryParams);

    print("getTodaysReport: Final URL: $url");
    print("getTodaysReport: Query params: $queryParams");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getTodaysReport: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("getTodaysReport: Success - Data keys: ${data.keys.toList()}");
        return data;
      } else {
        throw Exception(
          "Failed to load today's report: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("getTodaysReport: Exception: $e");
      throw Exception("Error fetching today's report: $e");
    }
  }

  static Future<Map<String, dynamic>> getDailyReport(
    DateTime date, {
    String? source,
    String? payment,
    String? orderType,
  }) async {
    final String dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final Map<String, String> queryParams = {};

    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri url = Uri.parse(
      _buildUrl('/admin/sales-report/daily2/$dateStr'),
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getDailyReport: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("getDailyReport: Success - Data keys: ${data.keys.toList()}");
        return data;
      } else {
        throw Exception("Failed to load daily report: ${response.statusCode}");
      }
    } catch (e) {
      print("getDailyReport: Exception: $e");
      throw Exception("Error fetching daily report: $e");
    }
  }

  static Future<Map<String, dynamic>> getWeeklyReport(
    DateTime date, {
    String? source,
    String? payment,
    String? orderType,
  }) async {
    final String dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final Map<String, String> queryParams = {};

    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri url = Uri.parse(
      _buildUrl('/admin/sales-report/weekly2/$dateStr'),
    ).replace(queryParameters: queryParams);

    print("getWeeklyReport: Final URL: $url");
    print("getWeeklyReport: Date: $dateStr");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getWeeklyReport: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("getWeeklyReport: Success - Data keys: ${data.keys.toList()}");
        return data;
      } else {
        throw Exception("Failed to load weekly report: ${response.statusCode}");
      }
    } catch (e) {
      print("getWeeklyReport: Exception: $e");
      throw Exception("Error fetching weekly report: $e");
    }
  }

  static Future<Map<String, dynamic>> getMonthlyReport(
    int year,
    int month, {
    String? source,
    String? payment,
    String? orderType,
  }) async {
    final Map<String, String> queryParams = {};

    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri url = Uri.parse(
      _buildUrl('/admin/sales-report/monthly2/$year/$month'),
    ).replace(queryParameters: queryParams);

    print("getMonthlyReport: Final URL: $url");
    print("getMonthlyReport: Query params: $queryParams");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getMonthlyReport: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("getMonthlyReport: Success - Data keys: ${data.keys.toList()}");
        return data;
      } else {
        throw Exception(
          "Failed to load monthly report: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("getMonthlyReport: Exception: $e");
      throw Exception("Error fetching monthly report: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getPostcodes() async {
    final url = Uri.parse(_buildUrl('/admin/postcodes'));
    print("getPostcodes: Attempting to fetch from URL: $url");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );

      print("getPostcodes: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['rows'] != null) {
          return List<Map<String, dynamic>>.from(data['rows']);
        } else {
          print("getPostcodes: No rows found in response");
          return [];
        }
      } else {
        print(
          "getPostcodes: Failed with status ${response.statusCode}: ${response.body}",
        );
        return [];
      }
    } catch (e) {
      print("getPostcodes: Error occurred: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDriverReport(DateTime date) async {
    final String dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final Uri url = Uri.parse(_buildUrl('/admin/driver-report/$dateStr'));

    print("getDriverReport: Final URL: $url");

    try {
      final response = await http.get(
        url,
        headers: BrandInfo.getDefaultHeaders(),
      );
      print("getDriverReport: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("getDriverReport: Success - Data keys: ${data.keys.toList()}");
        return data;
      } else {
        throw Exception("Failed to load driver report: ${response.statusCode}");
      }
    } catch (e) {
      print("getDriverReport: Exception: $e");
      throw Exception("Error fetching driver report: $e");
    }
  }

  static Future<Map<String, dynamic>> addItem({
    required String itemName,
    required String type,
    required String description,
    required Map<String, double> price,
    required Map<String, double> posPrice,
    required List<String> toppings,
    required bool website,
    String? subtype,
  }) async {
    final url = Uri.parse(_buildUrl('/item/add-items'));
    print("addItem: Attempting to add new item: $itemName");

    try {
      final requestBody = {
        "item_name": itemName,
        "type": type,
        "description": description,
        "price": price,
        "pos_price": posPrice,
        "toppings": toppings,
        "website": website,
      };

      if (subtype != null && subtype.isNotEmpty) {
        requestBody["subType"] = subtype;
      }

      print("addItem: Request body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(requestBody),
      );

      print("addItem: Response Code: ${response.statusCode}");
      print("addItem: Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("addItem: Successfully added item");
        return data;
      } else {
        throw Exception(
          "Failed to add item: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("addItem: Error adding item: $e");
      throw Exception("Error adding item: $e");
    }
  }

  static Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required String itemName,
    required String type,
    required String description,
    required Map<String, double> price,
    required Map<String, double> posPrice,
    required List<String> toppings,
    required bool website,
    required bool availability,
    String? subtype,
  }) async {
    final url = Uri.parse(_buildUrl('/item/update-item/$itemId'));
    print("updateItem: Attempting to update item ID: $itemId ($itemName)");

    try {
      final requestBody = {
        "item_name": itemName,
        "type": type,
        "description": description,
        "availability": availability,
        "price": price,
        "pos_price": posPrice,
        "toppings": toppings,
        "website": website,
      };

      if (subtype != null && subtype.isNotEmpty) {
        requestBody["subType"] = subtype;
      }

      print("updateItem: Request body: ${jsonEncode(requestBody)}");

      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(requestBody),
      );

      print("updateItem: Response Code: ${response.statusCode}");
      print("updateItem: Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("updateItem: Successfully updated item");
        return data;
      } else {
        throw Exception(
          "Failed to update item: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("updateItem: Error updating item: $e");
      throw Exception("Error updating item: $e");
    }
  }

  // Update order cart via PUT request
  Future<bool> updateOrderCart({
    required int orderId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required double discount,
    String? currentStatus,
  }) async {
    try {
      String? normalizedStatus;
      if (currentStatus != null) {
        final lowerStatus = currentStatus.toLowerCase();
        switch (lowerStatus) {
          case 'yellow':
          case 'pending':
          case 'accepted':
            normalizedStatus = 'pending';
            break;
          case 'green':
          case 'ready':
            normalizedStatus = 'confirmed';
            break;
          case 'preparing':
            normalizedStatus = 'preparing';
            break;
          case 'blue':
          case 'completed':
          case 'delivered':
            normalizedStatus = 'completed';
            break;
          default:
            normalizedStatus = lowerStatus;
        }
      }

      // CRITICAL: Only include status if it's NOT pending (backend may reject status changes on cart edits)
      final Map<String, dynamic> cartData = {
        'items': items,
        'total_price': totalPrice,
        'discount': discount,
        // Don't send status field for pending orders during cart edit
        if (normalizedStatus != null &&
            normalizedStatus.isNotEmpty &&
            normalizedStatus != 'pending')
          'status': normalizedStatus,
      };

      print('📤 Updating order #$orderId with data: ${jsonEncode(cartData)}');

      final response = await http.put(
        Uri.parse(_buildUrl('/orders/cart/edit/$orderId')),
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(cartData),
      );

      if (response.statusCode == 200) {
        print('✅ Order cart updated successfully for order #$orderId');
        print('✅ Response: ${response.body}');
        return true;
      } else {
        print('❌ Failed to update cart. Status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating order cart: $e');
      return false;
    }
  }

  // Fetch single order by ID
  Future<Map<String, dynamic>?> fetchOrderById(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse(_buildUrl('/orders/$orderId')),
        headers: BrandInfo.getDefaultHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('Failed to fetch order. Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching order: $e');
      return null;
    }
  }

  // Method to disable item from POS (sets pos: false)
  static Future<void> disableItemFromPOS(int itemId) async {
    final url = Uri.parse(_buildUrl('/item/disable-pos'));
    try {
      final response = await http.delete(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: json.encode({'item_id': itemId}),
      );

      if (response.statusCode == 200) {
        print('Item $itemId disabled from POS successfully');
      } else {
        print(
          'Failed to disable item from POS. Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception(
          'Failed to disable item from POS: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error disabling item from POS: $e');
      rethrow;
    }
  }
}

class OrderCreationResponse {
  final String? orderId;
  final String? orderNumber;

  OrderCreationResponse({required this.orderId, required this.orderNumber});
}
