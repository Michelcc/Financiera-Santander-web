import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente HTTP FastAPI — alineado con app Cliente.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String baseUrl = 'http://127.0.0.1:8003';
  static const String _tokenKey = 'asesor_jwt_token';
  static const Duration _timeout = Duration(seconds: 15);

  String? _cachedToken;

  Future<String?> getToken() async {
    _cachedToken ??=
        (await SharedPreferences.getInstance()).getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await (await SharedPreferences.getInstance()).setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
  }

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

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isEmpty ? null : jsonDecode(body);
    }
    String detail = 'Error ${response.statusCode}';
    try {
      final json = jsonDecode(body);
      if (json is Map && json['detail'] != null) {
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

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final response = await http
        .post(_uri(path),
            headers: await _headers(auth: auth), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final response = await http
        .get(_uri(path), headers: await _headers(auth: auth))
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
