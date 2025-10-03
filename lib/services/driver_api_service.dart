// lib/services/driver_api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DriverApiService {
  static const String baseUrl =
      "https://corsproxy.io/?https://api.dallasandgioschicken.uk";
  static const String alternativeProxy =
      "https://corsproxy.io/?https://api.dallasandgioschicken.uk";

  // Create Driver
  static Future<Map<String, dynamic>> createDriver({
    required String name,
    required String email,
    required String username,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/drivers/create'),
        headers: {'Content-Type': 'application/json', 'x-client-id': 'Dallas'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'username': username,
          'password': password,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        }),
      );

      print('Create Driver Response Status: ${response.statusCode}');
      print('Create Driver Response Body: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create driver');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      print('Error creating driver: $e');
      throw Exception('Failed to create driver: $e');
    }
  }

  // Deactivate Driver
  static Future<Map<String, dynamic>> deactivateDriver(String username) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/drivers/deactivate/$username'),
        headers: {'Content-Type': 'application/json', 'x-client-id': 'Dallas'},
      );

      print('Deactivate Driver Response Status: ${response.statusCode}');
      print('Deactivate Driver Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to deactivate driver');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      print('Error deactivating driver: $e');
      throw Exception('Failed to deactivate driver: $e');
    }
  }

  // Get Orders with Driver Details
  static Future<List<Map<String, dynamic>>> getOrdersWithDriver(
    String date,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/drivers/orders-with-driver/$date'),
        headers: {'Content-Type': 'application/json', 'x-client-id': 'Dallas'},
      );

      print('Get Orders with Driver Response Status: ${response.statusCode}');
      print('Get Orders with Driver Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['error'] ?? 'Failed to fetch orders with driver',
        );
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      print('Error fetching orders with driver: $e');
      throw Exception('Failed to fetch orders with driver: $e');
    }
  }
}
