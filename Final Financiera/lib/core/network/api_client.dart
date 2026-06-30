import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente HTTP que apunta al backend FastAPI (bd_core_mobile).
/// Puerto 8003 en la misma red WiFi que el servidor.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // ── Configuración ──────────────────────────────────────────────
  // Cambia esta IP a la de tu PC donde corre uvicorn --host 0.0.0.0 --port 8003
  static const String baseUrl = 'http://127.0.0.1:8003';
  static const String _tokenKey = 'cliente_jwt_token';

  static const Duration _timeout = Duration(seconds: 15);

  // ── Token JWT ──────────────────────────────────────────────────
  String? _cachedToken;

  Future<String?> getToken() async {
    _cachedToken ??= (await SharedPreferences.getInstance()).getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Cabeceras ──────────────────────────────────────────────────
  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) h[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    return h;
  }

  // ── Helpers ────────────────────────────────────────────────────
  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(body);
    }
    String detail = 'Error ${response.statusCode}';
    try {
      final json = jsonDecode(body);
      if (json is Map && json.containsKey('detail')) {
        detail = json['detail'].toString();
      }
    } catch (_) {}
    if (response.statusCode == 401) {
      throw ApiException(detail, statusCode: 401);
    }
    if (response.statusCode == 423) {
      throw ApiException('Usuario bloqueado por intentos fallidos', statusCode: 423);
    }
    throw ApiException(detail, statusCode: response.statusCode);
  }

  // ── Métodos HTTP ───────────────────────────────────────────────
  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final response = await http
        .post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> get(String path) async {
    final response = await http
        .get(_uri(path), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await http
        .patch(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isBlocked => statusCode == 423;

  @override
  String toString() => message;
}
