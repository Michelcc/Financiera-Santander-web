import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../src/core/app_config.dart';

class DniValidationResult {
  const DniValidationResult({
    required this.isValid,
    this.fullName,
    this.message,
  });

  final bool isValid;
  final String? fullName;
  final String? message;
}

class DniValidationService {
  DniValidationService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<DniValidationResult> validate(String rawDni) async {
    final dni = rawDni.replaceAll(RegExp(r'\D'), '');
    if (dni.length != 8) {
      return const DniValidationResult(
        isValid: false,
        message: 'Ingresa un DNI de 8 digitos.',
      );
    }

    if (!AppConfig.hasDniValidationApi) {
      return const DniValidationResult(isValid: true);
    }

    try {
      final response = await _client
          .get(_buildUri(dni), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return DniValidationResult(
          isValid: false,
          message: 'No se pudo validar el DNI (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const DniValidationResult(
          isValid: false,
          message: 'La respuesta de validacion no es valida.',
        );
      }

      final data = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
      final success = _successFlag(decoded) ?? _successFlag(data);
      final name = _fullName(data);

      if (success == false || name == null && data.isEmpty) {
        return DniValidationResult(
          isValid: false,
          message: _message(decoded) ?? 'DNI no encontrado.',
        );
      }

      return DniValidationResult(isValid: true, fullName: name);
    } on TimeoutException {
      return const DniValidationResult(
        isValid: false,
        message: 'La validacion de DNI tardo demasiado.',
      );
    } on FormatException {
      return const DniValidationResult(
        isValid: false,
        message: 'La API de DNI devolvio una respuesta invalida.',
      );
    } catch (_) {
      return const DniValidationResult(
        isValid: false,
        message: 'No se pudo conectar con la API de DNI.',
      );
    }
  }

  Uri _buildUri(String dni) {
    const template = AppConfig.dniValidationUrl;
    final value = template.contains('{dni}')
        ? template.replaceAll('{dni}', dni)
        : '${template.replaceFirst(RegExp(r'/+$'), '')}/$dni';
    final uri = Uri.parse(value);
    if (AppConfig.dniValidationToken.isEmpty ||
        uri.queryParameters.containsKey('token')) {
      return uri;
    }
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'token': AppConfig.dniValidationToken,
      },
    );
  }

  Map<String, String> get _headers {
    return {'Accept': 'application/json'};
  }

  static bool? _successFlag(Map<String, dynamic> json) {
    final value = json['success'] ?? json['valid'] ?? json['estado'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', 'ok', 'success', '1'].contains(normalized)) return true;
      if (['false', 'error', '0'].contains(normalized)) return false;
    }
    return null;
  }

  static String? _fullName(Map<String, dynamic> data) {
    final direct = _text(data['nombre']) ??
        _text(data['nombre_completo']) ??
        _text(data['nombreCompleto']) ??
        _text(data['full_name']);
    if (direct != null) return direct;

    final names = [
      _text(data['nombres']),
      _text(data['apellido_paterno']) ?? _text(data['apellidoPaterno']),
      _text(data['apellido_materno']) ?? _text(data['apellidoMaterno']),
    ].whereType<String>().join(' ').trim();
    return names.isEmpty ? null : names;
  }

  static String? _message(Map<String, dynamic> json) {
    return _text(json['message']) ??
        _text(json['mensaje']) ??
        _text(json['error']);
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
