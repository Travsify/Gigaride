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
  }

  Future<Map<String, dynamic>> registerPassenger({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'PASSENGER',
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'password': password,
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

  Future<Map<String, dynamic>> getEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/estimate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to get fare estimate');
  }

  Future<Map<String, dynamic>> createRideRequest({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required int riderOfferNgn,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAddress': pickupAddress,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'dropoffAddress': dropoffAddress,
        'riderOfferNgn': riderOfferNgn,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to create ride request');
  }

  // --- Living Wallet API Suite ---
  Future<Map<String, dynamic>> getLivingWallet() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/payments/wallet'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to load living wallet');
  }

  Future<Map<String, dynamic>> addMoney(int amountNgn, {String method = 'BANK_TRANSFER'}) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/wallet/add-money'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amountNgn': amountNgn, 'method': method}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to fund wallet');
  }

  Future<Map<String, dynamic>> swapWalletVault(String direction, int amountNgn) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/wallet/swap'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'direction': direction, 'amountNgn': amountNgn}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to swap funds');
  }

  Future<Map<String, dynamic>> withdrawFromWallet({
    required int amountNgn,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String bankCode = '000',
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/wallet/withdraw'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amountNgn': amountNgn,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'bankCode': bankCode,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to withdraw funds');
  }

  Future<List<dynamic>> getBeneficiaries({String? search, int days = 30}) async {
    final token = await getToken();
    String url = '$baseUrl/api/payments/wallet/beneficiaries?days=$days';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getStatement() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/payments/wallet/statement'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }
}
