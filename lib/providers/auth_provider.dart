import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxpdf/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _currentUser = '';
  String? _token;
  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  String get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading; // <-- Getter add kar diya

  AuthProvider() {
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUser = prefs.getString('user_name');

    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      _currentUser = savedUser ?? '';
      _isLoggedIn = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  // ============ REGISTER METHOD ============
  Future<void> register(
    String name,
    String email,
    String password,
    String confirmPassword,
  ) async {
    if (name.trim().isEmpty) {
      throw Exception('Please enter your name');
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long');
    }
    if (password != confirmPassword) {
      throw Exception('Passwords do not match');
    }

    try {
      await ApiService.register(
        name: name.trim(),
        email: email.trim(),
        password: password.trim(),
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ============ LOGIN METHOD ============
  Future<void> login(String email, String password) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address');
    }
    if (password.isEmpty) {
      throw Exception('Please enter your password');
    }

    try {
      final data = await ApiService.login(
        email: email.trim(),
        password: password.trim(),
      );

      _token = data['token'];
      _currentUser = data['user']?['name'] ?? email;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_name', _currentUser);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> resetPassword(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address');
    }
    return true;
  }

  // ============ LOGOUT METHOD (FIXED) ============
  Future<void> logout() async {
    // Storage se token aur user details remove karein
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_name');

    _isLoggedIn = false;
    _currentUser = '';
    _token = null;
    notifyListeners();
  }
}