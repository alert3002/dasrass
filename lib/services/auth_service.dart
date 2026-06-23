import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранение токена как `localStorage.token` во фронтенде.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _token;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
    notifyListeners();
  }

  Future<void> setToken(String? value) async {
    _token = value;
    final p = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await p.remove('token');
    } else {
      await p.setString('token', value);
    }
    notifyListeners();
  }
}
