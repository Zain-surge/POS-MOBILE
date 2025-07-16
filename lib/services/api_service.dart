import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/order.dart';


class ApiService {
  static const String baseUrl = "https://corsproxy.io/?https://thevillage-backend.onrender.com";
  static const String alternativeProxy = "https://thingproxy.freeboard.io/fetch/https://thevillage-backend.onrender.com";

  // Fetching menu items
  static Future<List<FoodItem>> fetchMenuItems() async {
    final url = Uri.parse("$baseUrl/item/items");
    print("fetchMenuItems: Attempting to fetch from URL: $url");
    try {
      final response = await http.get(url);
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

  // createOrder (method used by Page4's _submitOrder)
  static Future<String> createOrderFromMap(Map<String, dynamic> orderData) async {
    final url = Uri.parse("$alternativeProxy/orders/full-create");

    print('createOrderFromMap: Sending order data via proxy to URL: $url');
    print('createOrderFromMap: Order Data to send: ${jsonEncode(orderData)}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(orderData),
      );

      print('createOrderFromMap: Response Status Code: ${response.statusCode}');
      print('createOrderFromMap: Response Body: ${response.body}');

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

  // Shop Status Methods
  static Future<Map<String, dynamic>> getShopStatus() async {
    final url = Uri.parse("$baseUrl/admin/shop-status");
    print("getShopStatus: Attempting to fetch from URL: $url");

    try {
      final response = await http.get(url);
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
    // Try thingproxy first (which works for your createOrder)
    final primaryUrl = Uri.parse("$alternativeProxy/admin/shop-toggle");
    print("toggleShopStatus: Attempting to toggle shop status to: $shopOpen");

    try {
      final response = await http.put(
        primaryUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "shop_open": shopOpen,
        }),
      );

      print("toggleShopStatus: Response Code: ${response.statusCode}");
      print("toggleShopStatus: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop status updated successfully';
      } else {
        throw Exception("Failed to toggle shop status: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("toggleShopStatus: Primary proxy failed, trying fallback method: $e");

      // Fallback: Try using POST instead of PUT
      return await _toggleShopStatusFallback(shopOpen);
    }
  }

  static Future<String> _toggleShopStatusFallback(bool shopOpen) async {
    // Try multiple proxy services
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
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          },
          body: jsonEncode({
            "shop_open": shopOpen,
          }),
        );

        print("toggleShopStatus: Proxy Response Code: ${response.statusCode}");
        print("toggleShopStatus: Proxy Response Body: ${response.body}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['message'] ?? 'Shop status updated successfully';
        }
      } catch (e) {
        print("toggleShopStatus: Proxy $proxyUrl failed: $e");
        continue; // Try next proxy
      }
    }

    throw Exception("All proxy services failed for shop status toggle");
  }

  static Future<String> updateShopTimings(String openTime, String closeTime) async {
    // Try thingproxy first
    final primaryUrl = Uri.parse("$alternativeProxy/admin/update-shop-timings");
    print("updateShopTimings: Attempting to update shop timings - Open: $openTime, Close: $closeTime");

    try {
      final response = await http.put(
        primaryUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "shop_open_time": openTime,
          "shop_close_time": closeTime,
        }),
      );

      print("updateShopTimings: Response Code: ${response.statusCode}");
      print("updateShopTimings: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Shop timings updated successfully';
      } else {
        throw Exception("Failed to update shop timings: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("updateShopTimings: Primary proxy failed, trying fallback method: $e");

      // Fallback: Try using POST instead of PUT
      return await _updateShopTimingsFallback(openTime, closeTime);
    }
  }

  static Future<String> _updateShopTimingsFallback(String openTime, String closeTime) async {
    final fallbackUrl = Uri.parse("https://cors-anywhere.herokuapp.com/https://thevillage-backend.onrender.com/admin/update-shop-timings");
    print("updateShopTimings: Fallback - Attempting to update shop timings - Open: $openTime, Close: $closeTime");

    try {
      final response = await http.post(
        fallbackUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: jsonEncode({
          "shop_open_time": openTime,
          "shop_close_time": closeTime,
          "_method": "PUT", // Tell the server this is actually a PUT request
        }),
      );

      print("updateShopTimings: Fallback Response Code: ${response.statusCode}");
      print("updateShopTimings: Fallback Response Body: ${response.body}");

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
      final response = await http.get(url);
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
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "offer_text": offerText,
          "value": value,
        }),
      );

      print("updateOfferStatus: Response Code: ${response.statusCode}");
      print("updateOfferStatus: Response Body: ${response.body}");

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
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: jsonEncode({
          "offer_text": offerText,
          "value": value,
          "_method": "PUT",
        }),
      );

      print("updateOfferStatus: Fallback Response Code: ${response.statusCode}");
      print("updateOfferStatus: Fallback Response Body: ${response.body}");

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
  static Future<Map<String, dynamic>> getSalesReport() async {
    final url = Uri.parse("$baseUrl/admin/sales-report/today");
    print("getSalesReport: Attempting to fetch from URL: $url");

    try {
      final response = await http.get(url);
      print("getSalesReport: Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception("Failed to load sales report: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("getSalesReport: Error fetching sales report: $e");
      throw Exception("Error fetching sales report: $e");
    }
  }
}