import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AuthState extends ChangeNotifier {
  AuthState(this.apiClient);

  final ApiClient apiClient;

  String? _token;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  String? _error;
  String? get error => _error;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      _error = null;
      final token = await apiClient.login(email: email, password: password);
      _token = token;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String email, String password) async {
    _setLoading(true);
    try {
      _error = null;
      final token = await apiClient.register(email: email, password: password);
      _token = token;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _token = null;
    apiClient.setToken(null);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

