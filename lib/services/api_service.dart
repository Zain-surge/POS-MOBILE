// lib/services/api_service.dart (Updated with new sales report methods)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../config/brand_info.dart';

class ApiService {
  static const String baseUrl = "https://corsproxy.io/?https://thevillage-backend.onrender.com";
  static const String alternativeProxy = "https://corsproxy.io/?https://thevillage-backend.onrender.com";

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
        throw Exception("Failed to load menu items: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("fetchMenuItems: Error fetching items: $e");
      throw Exception("Error fetching menu items: $e");
    }
  }

  static Future<String> createOrderFromMap(Map<String, dynamic> orderData) async {
    final url = Uri.parse("$alternativeProxy/orders/full-create");

    try {
      final response = await http.post(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode(orderData),
      );

      print("Order body length: ${utf8.encode(jsonEncode(orderData)).length} bytes");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data.containsKey('error')) {
          print("Backend Error: ${data['error']}");
        }

        if (data.containsKey('order_id')) {
          return data['order_id'].toString();
        } else {
          print('createOrderFromMap: Warning: Backend response does not contain "order_id" key. Body: ${response.body}');
          return 'Order placed successfully (ID not returned from map)';
        }
      } else {
        throw Exception("Failed to create order from map: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('createOrderFromMap: CRITICAL ERROR during API call: $e');
      throw Exception('Failed to connect to the server or process request for order creation: $e');
    }
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
        throw Exception("Failed to load shop status: ${response.statusCode} - ${response.body}");
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
        body: jsonEncode({
          "shop_open": shopOpen,
        }),
      );

      print("toggleShopStatus: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop status updated successfully';
      } else {
        throw Exception("Failed to toggle shop status: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("toggleShopStatus: Primary proxy failed, trying fallback method: $e");
      return await _toggleShopStatusFallback(shopOpen);
    }
  }

  static Future<String> _toggleShopStatusFallback(bool shopOpen) async {
    final proxyUrls = [
      "https://api.allorigins.win/raw?url=https://thevillage-backend.onrender.com/admin/shop-toggle",
      "https://cors-anywhere.herokuapp.com/https://thevillage-backend.onrender.com/admin/shop-toggle",
      "https://crossorigin.me/https://thevillage-backend.onrender.com/admin/shop-toggle",
    ];

    for (String proxyUrl in proxyUrls) {
      try {
        print("toggleShopStatus: Trying proxy: $proxyUrl");
        final response = await http.put(
          Uri.parse(proxyUrl),
          headers: BrandInfo.getDefaultHeaders(),
          body: jsonEncode({
            "shop_open": shopOpen,
          }),
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

  static Future<String> updateShopTimings(String openTime, String closeTime) async {
    final primaryUrl = Uri.parse("$alternativeProxy/admin/update-shop-timings");
    print("updateShopTimings: Attempting to update shop timings - Open: $openTime, Close: $closeTime");

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
        throw Exception("Failed to update shop timings: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("updateShopTimings: Primary proxy failed, trying fallback method: $e");
      return await _updateShopTimingsFallback(openTime, closeTime);
    }
  }

  static Future<String> _updateShopTimingsFallback(String openTime, String closeTime) async {
    final fallbackUrl = Uri.parse("https://cors-anywhere.herokuapp.com/https://thevillage-backend.onrender.com/admin/update-shop-timings");
    print("updateShopTimings: Fallback - Attempting to update shop timings - Open: $openTime, Close: $closeTime");

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

      print("updateShopTimings: Fallback Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop timings updated successfully';
      } else {
        throw Exception("Failed to update shop timings: ${response.statusCode} - ${response.body}");
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
        throw Exception("Failed to load offers: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("getOffers: Error fetching offers: $e");
      throw Exception("Error fetching offers: $e");
    }
  }

  static Future<Map<String, dynamic>> updateOfferStatus(String offerText, bool value) async {
    final primaryUrl = Uri.parse("$alternativeProxy/admin/offers/update");
    print("updateOfferStatus: Attempting to update offer: $offerText to value: $value");

    try {
      final response = await http.put(
        primaryUrl,
        headers: BrandInfo.getDefaultHeaders(),
        body: jsonEncode({
          "offer_text": offerText,
          "value": value,
        }),
      );

      print("updateOfferStatus: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception("Failed to update offer status: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("updateOfferStatus: Primary proxy failed, trying fallback method: $e");
      return await _updateOfferStatusFallback(offerText, value);
    }
  }

  static Future<Map<String, dynamic>> _updateOfferStatusFallback(String offerText, bool value) async {
    final fallbackUrl = Uri.parse("https://cors-anywhere.herokuapp.com/https://thevillage-backend.onrender.com/admin/offers/update");
    print("updateOfferStatus: Fallback - Attempting to update offer: $offerText to value: $value");

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

      print("updateOfferStatus: Fallback Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception("Failed to update offer status: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("updateOfferStatus: Fallback also failed: $e");
      throw Exception("Error updating offer status: $e");
    }
  }

  static Future<FoodItem> setItemAvailability(int itemId, bool availability) async {
    final url = Uri.parse('https://proxy.corsfix.com/?url=https://thevillage-backend.onrender.com/item/set-availability');
    print("setItemAvailability (PUT): Attempting to update item availability for ID: $itemId to $availability");

    try {
      final response = await http.put(
        url,
        headers: BrandInfo.getDefaultHeaders(),
        body: json.encode({
          'item_id': itemId,
          'availability': availability,
        }),
      );

      print("setItemAvailability (PUT): Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('item')) {
          return FoodItem.fromJson(responseData['item']);
        } else {
          throw Exception('Failed to set item availability: "item" key missing in response.');
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to set item availability: ${response.statusCode} - ${errorBody['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print("setItemAvailability (PUT): Error setting item availability: $e");
      throw Exception('Error setting item availability: $e');
    }
  }

  static Future<Map<String, dynamic>> getTodaysReport({
    String? source,
    String? payment,
    String? orderType,
  }) async {
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://thevillage-backend.onrender.com";
    const String endpoint = "/admin/sales-report/today";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All') queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(backend + endpoint).replace(queryParameters: queryParams);
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
        return data;
      } else {
        print("getTodaysReport: Failed - ${response.statusCode}: ${response.body}");
        throw Exception("Failed to load today's report: ${response.statusCode}");
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
    const String backend = "https://thevillage-backend.onrender.com";
    final String dateStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final String endpoint = "/admin/sales-report/daily2/$dateStr";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All') queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(backend + endpoint).replace(queryParameters: queryParams);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

    print("getDailyReport: Final URL: $url");
    print("getDailyReport: Query params: $queryParams");

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
        print("getDailyReport: Failed - ${response.statusCode}: ${response.body}");
        throw Exception("Failed to load daily report: ${response.statusCode}");
      }
    } catch (e) {
      print("getDailyReport: Exception: $e");
      throw Exception("Error fetching daily report: $e");
    }
  }

  static Future<Map<String, dynamic>> getWeeklyReport(
      int year,
      int week, {
        String? source,
        String? payment,
        String? orderType,
      }) async {
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://thevillage-backend.onrender.com";
    final String endpoint = "/admin/sales-report/weekly2/$year/$week";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All') queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(backend + endpoint).replace(queryParameters: queryParams);
    final String encodedBackend = Uri.encodeComponent(backendUri.toString());
    final Uri url = Uri.parse(proxy + encodedBackend);

    print("getWeeklyReport: Final URL: $url");
    print("getWeeklyReport: Query params: $queryParams");

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
        print("getWeeklyReport: Failed - ${response.statusCode}: ${response.body}");
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
    const String backend = "https://thevillage-backend.onrender.com";
    final String endpoint = "/admin/sales-report/monthly2/$year/$month";

    final Map<String, String> queryParams = {};

    // FIXED: Don't convert to lowercase - use exact case as provided
    if (source != null && source != 'All') queryParams['source'] = source;
    if (payment != null && payment != 'All') queryParams['payment'] = payment;
    if (orderType != null && orderType != 'All') queryParams['orderType'] = orderType;

    final Uri backendUri = Uri.parse(backend + endpoint).replace(queryParameters: queryParams);
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
        print("getMonthlyReport: Failed - ${response.statusCode}: ${response.body}");
        throw Exception("Failed to load monthly report: ${response.statusCode}");
      }
    } catch (e) {
      print("getMonthlyReport: Exception: $e");
      throw Exception("Error fetching monthly report: $e");
    }
  }

  static Future<Map<String, dynamic>> getDriverReport(DateTime date) async {
    const String proxy = "https://corsproxy.io/?";
    const String backend = "https://thevillage-backend.onrender.com";
    final String dateStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
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
        print("getDriverReport: Failed - ${response.statusCode}: ${response.body}");
        throw Exception("Failed to load driver report: ${response.statusCode}");
      }
    } catch (e) {
      print("getDriverReport: Exception: $e");
      throw Exception("Error fetching driver report: $e");
    }
  }
}