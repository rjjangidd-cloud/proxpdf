import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Platform ke hisaab se URL decide hota hai
  static const bool isRealDevice = true;

  // Apna PC Wi-Fi IP yahan daalein (cmd me 'ipconfig' run karke check karein)
  static const String myWifiIp = '192.168.1.12'; // <-- Apna IPv4 yahan likhein

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/auth';
    } else if (isRealDevice) {
      // Real Phone / APK ke liye (Phone aur Laptop same Wi-Fi par hone chahiye)
      return 'http://$myWifiIp:5000/api/auth';
    } else {
      // Android Studio Emulator ke liye
      return 'http://10.0.2.2:5000/api/auth';
    }
  }

  // Common Headers
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // ================= REGISTER API CALL =================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ================= LOGIN API CALL =================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }
}
