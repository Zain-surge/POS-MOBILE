import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/order.dart';

class ApiService {

  // Fetching menu items
  static Future<List<FoodItem>> fetchMenuItems() async {

    final url = Uri.parse("https://corsproxy.io/?https://thevillage-backend.onrender.com/item/items");
    print("fetchMenuItems: Attempting to fetch from URL: $url");
    try {
      final response = await http.get(url);
      print("fetchMenuItems: Response Code: ${response.statusCode}");

     //print("Response Body: ${response.body}");
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

   // final url = Uri.parse("https://api.allorigins.win/raw?url=${Uri.encodeComponent('https://thevillage-backend.onrender.com/orders/full-create')}");
   // final url = Uri.parse("https://corsproxy.io/?https://thevillage-backend.onrender.com/orders/full-create");
    final url = Uri.parse("https://thingproxy.freeboard.io/fetch/https://thevillage-backend.onrender.com/orders/full-create");


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
          //return data['order_id'];
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
}






