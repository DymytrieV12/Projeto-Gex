import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = 'https://api.sandbox.greenexpress.com.br';

  static String? _token;
  static String? _userId;

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
  }

  static Future<bool> isAuthenticated() async {
    await _loadToken();
    return _token != null && _userId != null;
  }

  static String? get userId => _userId;

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
        return {
          'success': false,
          'error': 'Credenciais inválidas (${response.statusCode})',
        };
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
        return {'success': false, 'error': 'ID do revendedor não encontrado no token'};
      }

      _token = token;
      _userId = userId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('userId', userId);

      return {
        'success': true,
        'payload': payload,
      };
    } catch (e) {
      return {'success': false, 'error': 'Erro de conexão: $e'};
    }
  }

  static Future<void> logout() async {
    _token = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  static Future<Map<String, dynamic>> getProdutos({int page = 1, int pageSize = 50}) async {
    await _loadToken();
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/produtos?page=$page&pageSize=$pageSize'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getRevendedor() async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/revendedor/$_userId'), headers: _headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateRevendedor(Map<String, dynamic> data) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/revendedor/$_userId'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}: ${response.body}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getEnderecoRevendedor() async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/enderecorevendedor/$_userId'), headers: _headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return {'success': true, 'data': null};
        return {'success': true, 'data': jsonDecode(body)};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateEnderecoRevendedor(Map<String, dynamic> data) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/enderecorevendedor/$_userId'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}: ${response.body}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPedidosRevendedor({int page = 1, int pageSize = 100}) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/pedidosrevendedor/$_userId?page=$page&pageSize=$pageSize'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sessão expirada', 'unauthorized': true};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> criarPedido({
    required int formaPagamentoId,
    required int tipoEntrega,
    required int quantidadeParcela,
    required double valorTotal,
    required List<Map<String, dynamic>> produtos,
    double? valorFrete,
    String observacao = '',
    double valorGreenCash = 0,
  }) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final body = {
        'revendedorId': int.tryParse(_userId!) ?? 0,
        'formaPagamentoId': formaPagamentoId,
        'tipoEntrega': tipoEntrega,
        'quantidadeParcela': quantidadeParcela,
        'valorTotal': valorTotal,
        'produtos': produtos,
        'observacao': observacao,
        'valorGreenCash': valorGreenCash,
        'valorFrete': valorFrete ?? 0,
        'valorDesconto': 0,
        'cupomDescontoId': null,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/pedidosrevendedor'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final bodyText = response.body.trim();
        if (bodyText.isEmpty) return {'success': true, 'data': {}};
        try {
          return {'success': true, 'data': jsonDecode(bodyText)};
        } catch (_) {
          return {'success': true, 'data': {'message': bodyText}};
        }
      }

      final raw = response.body.trim();
      if (raw.contains('Credenciais inválidas')) {
        return {
          'success': false,
          'error': 'A API do sandbox recusou a criação do pedido com a mensagem "Credenciais inválidas". O app está enviando para a rota correta, mas o backend precisa ser ajustado no servidor.',
          'backendError': raw,
        };
      }

      return {
        'success': false,
        'error': 'Erro ${response.statusCode}: $raw',
      };
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDescontoProgressivo() async {
    await _loadToken();
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/pedidosrevendedor/desconto-progressivo'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getFormasPagamento() async {
    await _loadToken();
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/formaspagamentos'), headers: _headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTiposEntrega() async {
    await _loadToken();
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/tiposentregapedido'), headers: _headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>> calcularFrete({
    required int tipoEntrega,
    required double valorTotal,
  }) async {
    await _loadToken();
    if (_userId == null) return {'success': false, 'error': 'Não autenticado'};

    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/frete?tipoEntrega=$tipoEntrega&colaboradorId=$_userId&valorTotal=$valorTotal&clienteRepresentanteId=$_userId',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return {
            'success': true,
            'data': {'valorFrete': 0.0},
          };
        }
        try {
          return {'success': true, 'data': jsonDecode(body)};
        } catch (_) {
          return {
            'success': true,
            'data': {'valorFrete': 0.0},
          };
        }
      }
      return {'success': false, 'error': 'Erro ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Erro: $e'};
    }
  }
}
