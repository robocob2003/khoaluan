// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../config/app_config.dart';

class ApiService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 10);
  final http.Client _client = http.Client();

  Future<bool> checkConnection() async {
    try {
      final response =
          await _client.get(Uri.parse('$_baseUrl/health')).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      print('Connection check failed: $e');
      return false;
    }
  }

  Future<bool> register(
      String username, String email, String password, String publicKey) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'email': email,
              'password': password,
              'publicKey': publicKey,
            }),
          )
          .timeout(_timeout);

      return response.statusCode == 201;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<Map<String, String>?> login(String username, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'publicKey': data['publicKey'] ?? ''};
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final response =
          await _client.get(Uri.parse('$_baseUrl/users')).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = json.decode(response.body);
        return usersJson.map((json) => UserModel.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get users error: $e');
      return [];
    }
  }

  // ---- HÀM MỚI ĐÃ THÊM ----
  Future<bool> updateProfile(String username, String email) async {
    try {
      final response = await _client
          .put(
            Uri.parse('$_baseUrl/update-profile'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'email': email,
            }),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }
  // -------------------------

  void dispose() {
    _client.close();
  }
}
