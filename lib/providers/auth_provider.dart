import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  Revendedor? _revendedor;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  Revendedor? get revendedor => _revendedor;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;

  /// Verifica se há sessão válida (token não expirado)
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      // isAuthenticated agora valida expiração do JWT
      _isAuthenticated = await ApiService.isAuthenticated();

      if (_isAuthenticated) {
        await _loadRev();
      } else {
        // Token expirado ou inexistente — limpar estado
        _revendedor = null;
      }
    } catch (_) {
      _isAuthenticated = false;
      _revendedor = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String senha) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final r = await ApiService.login(email, senha);

      if (r['success'] == true) {
        _isAuthenticated = true;
        final payload = r['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          _revendedor = Revendedor.fromJwtPayload(payload);
        }
        await _loadRev();
        return true;
      } else {
        _errorMessage = r['error']?.toString();
        _isAuthenticated = false;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro: $e';
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRev() async {
    try {
      final r = await ApiService.getRevendedor();
      if (r['success'] == true && r['data'] != null) {
        _revendedor = Revendedor.fromJson(r['data'] as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshRevendedor() async => await _loadRev();

  Future<void> logout() async {
    await ApiService.logout();
    _isAuthenticated = false;
    _revendedor = null;
    _errorMessage = null;
    notifyListeners();
  }
}
