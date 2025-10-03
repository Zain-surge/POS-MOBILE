// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../config/brand_info.dart';
import '../models/paidout_models.dart';

class ApiService {
  static const String baseUrl =
      "https://corsproxy.io/?https://api.dallasandgioschicken.uk";
  static const String alternativeProxy =
      "https://corsproxy.io/?https://api.dallasandgioschicken.uk";

  // Method to mark order as paid
  static Future<bool> markOrderAsPaid(int orderId) async {
    final url = Uri.parse("$baseUrl/item/set-paid-status");
    try {
      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({'order_id': orderId, 'paid_status': true}),
      );
      print("markOrderAsPaid: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("Order $orderId marked as paid successfully");
        return true;
      } else {
        print(
          "Failed to mark order as paid: ${response.statusCode} - ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("Error marking order as paid: $e");
      return false;
    }
  }

  static Future<List<FoodItem>> fetchMenuItems() async {
    final url = Uri.parse("$baseUrl/item/items");
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

  static Future<String> createOrderFromMap(
    Map<String, dynamic> orderData,
  ) async {
    final url = Uri.parse("$alternativeProxy/orders/full-create");
    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(orderData),
      );

      print(
        "Order body length: ${utf8.encode(jsonEncode(orderData)).length} bytes",
      );
      print("📤 DEBUG: Response status: ${response.statusCode}");
      print("📤 DEBUG: Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data.containsKey('error')) {
          print("Backend Error: ${data['error']}");
        }

        if (data.containsKey('order_id')) {
          print(
            "📤 DEBUG: Successfully created order with ID: ${data['order_id']}",
          );
          return data['order_id'].toString();
        } else {
          print(
            'createOrderFromMap: Warning: Backend response does not contain "order_id" key. Body: ${response.body}',
          );
          return 'Order placed successfully (ID not returned from map)';
        }
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

  // FIXED: Submit paid outs with correct endpoint and format
  static Future<void> submitPaidOuts(List<PaidOut> paidOuts) async {
    final url = Uri.parse("$alternativeProxy/admin/paidouts");

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

  // FIXED: Get today's paid outs with correct endpoint and consistent proxy usage
  static Future<List<PaidOutRecord>> getTodaysPaidOuts() async {
    final url = Uri.parse("$alternativeProxy/admin/paidouts/today");
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
        // Try alternative endpoint patterns
        print(
          "getTodaysPaidOuts: Primary endpoint failed, trying alternatives...",
        );
        return await _getTodaysPaidOutsFallback();
      }
    } catch (e) {
      print("getTodaysPaidOuts: Primary method failed: $e");
      // Try fallback method
      return await _getTodaysPaidOutsFallback();
    }
  }

  // FALLBACK: Try different endpoint patterns for getting today's paid outs
  static Future<List<PaidOutRecord>> _getTodaysPaidOutsFallback() async {
    final alternativeEndpoints = [
      "$alternativeProxy/paidouts/today",
      "$baseUrl/paidouts/today",
      "$alternativeProxy/paidouts",
      "$baseUrl/paidouts",
    ];

    for (String endpoint in alternativeEndpoints) {
      try {
        print("getTodaysPaidOuts: Trying alternative endpoint: $endpoint");

        final response = await http.get(
          Uri.parse(endpoint),
          headers: BrandInfo.getDefaultHeaders(),
        );

        print(
          "getTodaysPaidOuts: Alternative endpoint response: ${response.statusCode}",
        );

        if (response.statusCode == 200) {
          final responseBody = response.body;
          print(
            "getTodaysPaidOuts: Alternative endpoint response body: $responseBody",
          );

          // Handle different response formats
          dynamic data;
          try {
            data = jsonDecode(responseBody);
          } catch (e) {
            print("getTodaysPaidOuts: Failed to parse JSON: $e");
            continue;
          }

          // Handle different data structures
          List<dynamic> paidOutsList;
          if (data is List) {
            paidOutsList = data;
          } else if (data is Map && data.containsKey('paidouts')) {
            paidOutsList = data['paidouts'];
          } else if (data is Map && data.containsKey('data')) {
            paidOutsList = data['data'];
          } else {
            print(
              "getTodaysPaidOuts: Unexpected response structure: ${data.runtimeType}",
            );
            continue;
          }

          print(
            "getTodaysPaidOuts: Successfully found ${paidOutsList.length} records",
          );
          return paidOutsList
              .map((json) => PaidOutRecord.fromJson(json))
              .toList();
        }
      } catch (e) {
        print("getTodaysPaidOuts: Alternative endpoint $endpoint failed: $e");
        continue;
      }
    }

    throw Exception(
      "All paid outs endpoints failed. The API might be down or the endpoint structure has changed.",
    );
  }

  static Future<Map<String, dynamic>> getShopStatus() async {
    final url = Uri.parse("$baseUrl/admin/shop-status");
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
    final primaryUrl = Uri.parse("$alternativeProxy/admin/shop-toggle");
    print("toggleShopStatus: Attempting to toggle shop status to: $shopOpen");

    try {
      final response = await http.put(
        primaryUrl,
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
      print(
        "toggleShopStatus: Primary proxy failed, trying fallback method: $e",
      );
      return await _toggleShopStatusFallback(shopOpen);
    }
  }

  static Future<String> _toggleShopStatusFallback(bool shopOpen) async {
    final proxyUrls = [
      "https://api.allorigins.win/raw?url=https://api.dallasandgioschicken.uk/admin/shop-toggle",
      "https://cors-anywhere.herokuapp.com/https://api.dallasandgioschicken.uk/admin/shop-toggle",
      "https://crossorigin.me/https://api.dallasandgioschicken.uk/admin/shop-toggle",
    ];

    for (String proxyUrl in proxyUrls) {
      try {
        print("toggleShopStatus: Trying proxy: $proxyUrl");
        final response = await http.put(
          Uri.parse(proxyUrl),
          headers: BrandInfo.getDefaultHeaders(),
          body: jsonEncode({"shop_open": shopOpen}),
        );

        print("toggleShopStatus: Proxy Response Code: ${response.statusCode}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['message'] ?? 'Shop status updated successfully';
        }
      } catch (e) {
        print("toggleShopStatus: Proxy $proxyUrl failed: $e");
        continue;
      }
    }

    throw Exception("All proxy services failed for shop status toggle");
  }

  static Future<String> updateShopTimings(
    String openTime,
    String closeTime,
  ) async {
    final primaryUrl = Uri.parse("$alternativeProxy/admin/update-shop-timings");
    print(
      "updateShopTimings: Attempting to update shop timings - Open: $openTime, Close: $closeTime",
    );

    try {
      final response = await http.put(
        primaryUrl,
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
      print(
        "updateShopTimings: Primary proxy failed, trying fallback method: $e",
      );
      return await _updateShopTimingsFallback(openTime, closeTime);
    }
  }

  static Future<String> _updateShopTimingsFallback(
    String openTime,
    String closeTime,
  ) async {
    final fallbackUrl = Uri.parse(
      "https://cors-anywhere.herokuapp.com/https://api.dallasandgioschicken.uk/admin/update-shop-timings",
    );
    print(
      "updateShopTimings: Fallback - Attempting to update shop timings - Open: $openTime, Close: $closeTime",
    );

    try {
      final response = await http.post(
        fallbackUrl,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({
          "shop_open_time": openTime,
          "shop_close_time": closeTime,
          "_method": "PUT",
        }),
      );

      print(
        "updateShopTimings: Fallback Response Code: ${response.statusCode}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop timings updated successfully';
      } else {
        throw Exception(
          "Failed to update shop timings: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("updateShopTimings: Fallback also failed: $e");
      throw Exception("Error updating shop timings: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getOffers() async {
    final url = Uri.parse("$baseUrl/admin/offers");
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
    final primaryUrl = Uri.parse("$alternativeProxy/admin/offers/update");
    print(
      "updateOfferStatus: Attempting to update offer: $offerText to value: $value",
    );

    try {
      final response = await http.put(
        primaryUrl,
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
      print(
        "updateOfferStatus: Primary proxy failed, trying fallback method: $e",
      );
      return await _updateOfferStatusFallback(offerText, value);
    }
  }

  static Future<Map<String, dynamic>> _updateOfferStatusFallback(
    String offerText,
    bool value,
  ) async {
    final fallbackUrl = Uri.parse(
      "https://cors-anywhere.herokuapp.com/https://api.dallasandgioschicken.uk/admin/offers/update",
    );

    try {
      final response = await http.post(
        fallbackUrl,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({
          "offer_text": offerText,
          "value": value,
          "_method": "PUT",
        }),
      );

      print(
        "updateOfferStatus: Fallback Response Code: ${response.statusCode}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          "Failed to update offer status: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("updateOfferStatus: Fallback also failed: $e");
      throw Exception("Error updating offer status: $e");
    }
  }

  static Future<FoodItem> setItemAvailability(
    int itemId,
    bool availability,
  ) async {
    // Use consistent CORS proxy like other methods
    final primaryUrl = Uri.parse("$alternativeProxy/item/set-availability");
    print(
      "ApiService: Attempting to update item availability for ID: $itemId to $availability",
    );

    try {
      final response = await http
          .put(
            primaryUrl,
            headers: BrandInfo.getDefaultHeaders(),
            body: json.encode({
              'item_id': itemId,
              'availability': availability,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
          ); // Add timeout for production reliability

      print(
        "ApiService: setItemAvailability Response Code: ${response.statusCode}",
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('item')) {
          return FoodItem.fromJson(responseData['item']);
        } else {
          throw Exception(
            'Failed to set item availability: "item" key missing in response.',
          );
        }
      } else {
        // Handle error response more safely for release mode
        String errorMessage = 'Unknown error';
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['message'] ?? 'Unknown error';
        } catch (parseError) {
          print("ApiService: Failed to parse error response: $parseError");
          errorMessage =
              response.body.isNotEmpty ? response.body : 'Network error';
        }
        throw Exception(
          'Failed to set item availability: ${response.statusCode} - $errorMessage',
        );
      }
    } catch (e) {
      print("ApiService: Primary proxy failed for setItemAvailability: $e");
      // Try fallback method like other API calls
      return await _setItemAvailabilityFallback(itemId, availability);
    }
  }

  // Fallback method for setItemAvailability with multiple proxy attempts
  static Future<FoodItem> _setItemAvailabilityFallback(
    int itemId,
    bool availability,
  ) async {
    final fallbackProxies = [
      "https://cors-anywhere.herokuapp.com/https://api.dallasandgioschicken.uk/item/set-availability",
      "https://api.allorigins.win/raw?url=https://api.dallasandgioschicken.uk/item/set-availability",
      "https://proxy.corsfix.com/?url=https://api.dallasandgioschicken.uk/item/set-availability",
    ];

    for (String proxyUrl in fallbackProxies) {
      try {
        print(
          "ApiService: Trying fallback proxy for setItemAvailability: $proxyUrl",
        );

        final response = await http
            .put(
              Uri.parse(proxyUrl),
              headers: BrandInfo.getDefaultHeaders(),
              body: json.encode({
                'item_id': itemId,
                'availability': availability,
              }),
            )
            .timeout(const Duration(seconds: 10));

        print("ApiService: Fallback proxy response: ${response.statusCode}");

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData.containsKey('item')) {
            return FoodItem.fromJson(responseData['item']);
          } else {
            throw Exception(
              'Failed to set item availability: "item" key missing in response.',
            );
          }
        }
      } catch (e) {
        print("ApiService: Fallback proxy $proxyUrl failed: $e");
        continue;
      }
    }

    throw Exception(
      "All proxy services failed for item availability update. Please check your internet connection.",
    );
  }

  static Future<Map<String, dynamic>> getTodaysReport({
    String? source,
    String? payment,
    String? orderType,
  }) async {
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://api.dallasandgioschicken.uk";
    const String endpoint = "/admin/sales-report/today";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(
      backend + endpoint,
    ).replace(queryParameters: queryParams);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

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

        // Debug: Print all the data to see what we're getting
        print("getTodaysReport: Full response data:");
        data.forEach((key, value) {
          print("  $key: $value (type: ${value.runtimeType})");
        });

        return data;
      } else {
        print(
          "getTodaysReport: Failed - ${response.statusCode}: ${response.body}",
        );
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
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://api.dallasandgioschicken.uk";
    final String dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final String endpoint = "/admin/sales-report/daily2/$dateStr";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(
      backend + endpoint,
    ).replace(queryParameters: queryParams);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

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
        print(
          "getDailyReport: Failed - ${response.statusCode}: ${response.body}",
        );
        throw Exception("Failed to load daily report: ${response.statusCode}");
      }
    } catch (e) {
      print("getDailyReport: Exception: $e");
      throw Exception("Error fetching daily report: $e");
    }
  }

  static Future<Map<String, dynamic>> getWeeklyReport(
    DateTime date, { // Changed from (int year, int week) to (DateTime date)
    String? source,
    String? payment,
    String? orderType,
  }) async {
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://api.dallasandgioschicken.uk";
    final String dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final String endpoint =
        "/admin/sales-report/weekly2/$dateStr"; // Updated endpoint

    final Map<String, String> queryParams = {};

    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(
      backend + endpoint,
    ).replace(queryParameters: queryParams);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

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
        print(
          "getWeeklyReport: Failed - ${response.statusCode}: ${response.body}",
        );
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
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://api.dallasandgioschicken.uk";
    final String endpoint = "/admin/sales-report/monthly2/$year/$month";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All')
      queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(
      backend + endpoint,
    ).replace(queryParameters: queryParams);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

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
        print(
          "getMonthlyReport: Failed - ${response.statusCode}: ${response.body}",
        );
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
    final url = Uri.parse("$baseUrl/admin/postcodes");
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
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://api.dallasandgioschicken.uk";
    final String dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final String endpoint = "/admin/driver-report/$dateStr";

    final Uri backendUri = Uri.parse(backend + endpoint);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

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
        print(
          "getDriverReport: Failed - ${response.statusCode}: ${response.body}",
        );
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
    required List<String> toppings,
    required bool website,
    String? subtype,
  }) async {
    final url = Uri.parse("$baseUrl/item/add-items");
    print("addItem: Attempting to add new item: $itemName");

    try {
      final requestBody = {
        "item_name": itemName,
        "type": type,
        "description": description,
        "price": price, // Now sending as Map<String, double> for JSONB field
        "toppings": toppings,
        "website": website,
      };

      // Add subtype if provided (backend expects "subType")
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
}
