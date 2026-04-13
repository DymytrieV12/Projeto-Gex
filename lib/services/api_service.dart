import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Callback global para sessão expirada — dispara redirect no main.dart
typedef SessionExpiredCallback = void Function();

class ApiService {
  static const String _baseUrl = 'https://api.sandbox.greenexpress.com.br';

  static String? _token;
  static String? _userId;
  static int? _tokenExp; // Unix timestamp de expiração

  /// Callback chamado quando qualquer request retorna 401
  static SessionExpiredCallback? onSessionExpired;

  static Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  static Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _tokenExp = prefs.getInt('tokenExp');
  }

  /// Verifica se o token existe E não está expirado
  static Future<bool> isAuthenticated() async {
    await _loadToken();
    if (_token == null || _userId == null) return false;

    // Verificar expiração do JWT
    if (_tokenExp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= _tokenExp!) {
        // Token expirado — limpar tudo
        await logout();
        return false;
      }
    } else {
      // Sem exp salvo — tentar decodificar do token
      final exp = _extractExp(_token!);
      if (exp != null) {
        _tokenExp = exp;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('tokenExp', exp);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now >= exp) {
          await logout();
          return false;
        }
      }
    }

    return true;
  }

  /// Extrai campo "exp" do payload JWT
  static int? _extractExp(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      return (payload['exp'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static String? get userId => _userId;

  /// Handler global de 401 — dispara sessão expirada
  static void _handle401() {
    _token = null;
    _userId = null;
    _tokenExp = null;
    SharedPreferences.getInstance().then((p) {
      p.remove('token');
      p.remove('userId');
      p.remove('tokenExp');
    });
    onSessionExpired?.call();
  }

  static Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/autenticar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'login': email, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return {'success': false, 'error': 'Credenciais inválidas (${response.statusCode})'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Token inválido'};
      }

      final parts = token.split('.');
      if (parts.length != 3) {
        return {'success': false, 'error': 'Formato do token inválido'};
      }

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final userId = payload['nameid']?.toString() ?? '';
      if (userId.isEmpty) {
        return {'success': false, 'error': 'ID do revendedor não encontrado'};
      }

      final exp = (payload['exp'] as num?)?.toInt();

      _token = token;
      _userId = userId;
      _tokenExp = exp;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('userId', userId);
      if (exp != null) await prefs.setInt('tokenExp', exp);

      return {'success': true, 'payload': payload};
    } catch (e) {
      return {'success': false, 'error': 'Erro de conexão: $e'};
    }
  }

  static Future<void> logout() async {
    _token = null;
    _userId = null;
    _tokenExp = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('tokenExp');
  }

  /// Wrapper que intercepta 401 em qualquer chamada
  static Future<Map<String, dynamic>> _safeGet(String url) async {
    await _loadToken();

    // Checar expiração antes de chamar
    if (_tokenExp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= _tokenExp!) {
        _handle401();
        return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true};
      }
    }

    try {
      final r = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) return {'success': true, 'data': jsonDecode(r.body)};
      if (r.statusCode == 401) { _handle401(); return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true}; }
      return {'success': false, 'error': 'Erro ${r.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProdutos({int page = 1, int pageSize = 50}) async {
    return _safeGet('$_baseUrl/api/produtos?page=$page&pageSize=$pageSize');
  }

  static Future<Map<String, dynamic>> getRevendedor() async {
    if (_userId == null) { await _loadToken(); if (_userId == null) return {'success': false, 'error': 'Não autenticado'}; }
    return _safeGet('$_baseUrl/api/revendedor/$_userId');
  }

  static Future<Map<String, dynamic>> updateRevendedor(Map<String, dynamic> data) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};
    try {
      final r = await http.put(Uri.parse('$_baseUrl/api/revendedor/$_userId'), headers: _headers, body: jsonEncode(data)).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) return {'success': true};
      if (r.statusCode == 401) { _handle401(); return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true}; }
      return {'success': false, 'error': 'Erro ${r.statusCode}: ${r.body}'};
    } catch (e) { return {'success': false, 'error': 'Erro: $e'}; }
  }

  static Future<Map<String, dynamic>> getEnderecoRevendedor() async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/enderecorevendedor/$_userId'), headers: _headers).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) { final b = r.body.trim(); return b.isEmpty ? {'success': true, 'data': null} : {'success': true, 'data': jsonDecode(b)}; }
      if (r.statusCode == 401) { _handle401(); return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true}; }
      return {'success': false, 'error': 'Erro ${r.statusCode}'};
    } catch (e) { return {'success': false, 'error': 'Erro: $e'}; }
  }

  static Future<Map<String, dynamic>> updateEnderecoRevendedor(Map<String, dynamic> data) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};
    try {
      final r = await http.put(Uri.parse('$_baseUrl/api/enderecorevendedor/$_userId'), headers: _headers, body: jsonEncode(data)).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) return {'success': true};
      if (r.statusCode == 401) { _handle401(); return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true}; }
      return {'success': false, 'error': 'Erro ${r.statusCode}: ${r.body}'};
    } catch (e) { return {'success': false, 'error': 'Erro: $e'}; }
  }

  static Future<Map<String, dynamic>> getPedidosRevendedor({int page = 1, int pageSize = 100}) async {
    if (_userId == null) { await _loadToken(); if (_userId == null) return {'success': false, 'error': 'Não autenticado'}; }
    return _safeGet('$_baseUrl/api/pedidosrevendedor/$_userId?page=$page&pageSize=$pageSize');
  }

  static Future<Map<String, dynamic>> getDescontoProgressivo() async {
    return _safeGet('$_baseUrl/api/pedidosrevendedor/desconto-progressivo');
  }

  static Future<Map<String, dynamic>> criarPedido({
    required int formaPagamentoId, required int tipoEntrega, required int quantidadeParcela,
    required double valorTotal, required List<Map<String, dynamic>> produtos,
    double? valorFrete, String observacao = '', double valorGreenCash = 0,
  }) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    // Checar expiração
    if (_tokenExp != null && DateTime.now().millisecondsSinceEpoch ~/ 1000 >= _tokenExp!) {
      _handle401();
      return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true};
    }

    try {
      final body = {
        'revendedorId': int.tryParse(_userId!) ?? 0,
        'formaPagamentoId': formaPagamentoId, 'tipoEntrega': tipoEntrega,
        'quantidadeParcela': quantidadeParcela, 'valorTotal': valorTotal,
        'produtos': produtos, 'observacao': observacao,
        'valorGreenCash': valorGreenCash, 'valorFrete': valorFrete ?? 0,
        'valorDesconto': 0, 'cupomDescontoId': null,
      };
      final r = await http.post(Uri.parse('$_baseUrl/api/pedidosrevendedor'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200 || r.statusCode == 201) {
        final b = r.body.trim();
        if (b.isEmpty) return {'success': true, 'data': {}};
        try { return {'success': true, 'data': jsonDecode(b)}; } catch (_) { return {'success': true, 'data': {'message': b}}; }
      }
      if (r.statusCode == 401) { _handle401(); return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true}; }
      final raw = r.body.trim();
      if (raw.contains('Credenciais inválidas')) {
        return {'success': false, 'error': 'Erro no backend: Credenciais inválidas', 'backendError': raw};
      }
      return {'success': false, 'error': 'Erro ${r.statusCode}: $raw'};
    } catch (e) { return {'success': false, 'error': 'Erro: $e'}; }
  }

  static Future<Map<String, dynamic>> getFormasPagamento() async => _safeGet('$_baseUrl/api/formaspagamentos');
  static Future<Map<String, dynamic>> getTiposEntrega() async => _safeGet('$_baseUrl/api/tiposentregapedido');

  static Future<Map<String, dynamic>> calcularFrete({required int tipoEntrega, required double valorTotal}) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/frete?tipoEntrega=$tipoEntrega&colaboradorId=$_userId&valorTotal=$valorTotal&clienteRepresentanteId=$_userId'), headers: _headers).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) { final b = r.body.trim(); if (b.isEmpty) return {'success': true, 'data': {'valorFrete': 0.0}}; try { return {'success': true, 'data': jsonDecode(b)}; } catch (_) { return {'success': true, 'data': {'valorFrete': 0.0}}; } }
      if (r.statusCode == 401) { _handle401(); return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true}; }
      return {'success': false, 'error': 'Erro ${r.statusCode}'};
    } catch (e) { return {'success': false, 'error': 'Erro: $e'}; }
  }
}
