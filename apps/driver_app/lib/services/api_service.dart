import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class ApiService {
  String baseUrl = AppConstants.defaultApiUrl;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  Future<Map<String, dynamic>> registerDriver({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String licensePlate,
    required String vehicleColor,
    String? nin,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'DRIVER',
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'password': password,
        'vehicleMake': vehicleMake,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'licensePlate': licensePlate,
        'vehicleColor': vehicleColor,
        'nin': nin,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      await saveToken(data['data']['token']);
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      await saveToken(data['data']['token']);
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to load profile');
  }

  Future<List<dynamic>> getSubscriptionPlans() async {
    final response = await http.get(Uri.parse('$baseUrl/api/subscriptions/plans'));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception('Failed to load subscription plans');
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/subscriptions/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to get subscription status');
  }

  Future<Map<String, dynamic>> purchaseSubscription(String planId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/subscriptions/purchase'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'planId': planId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Purchase failed');
  }
}
