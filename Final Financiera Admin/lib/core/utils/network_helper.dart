import 'dart:io';

import '../../src/core/app_config.dart';

class NetworkHelper {
  static const offlineMessage =
      'Sin conexión a internet. Active WiFi o datos móviles.';

  static bool isNetworkError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('host lookup') ||
        raw.contains('socketfailed') ||
        raw.contains('no address associated with hostname') ||
        raw.contains('clientexception') ||
        raw.contains('network is unreachable') ||
        raw.contains('failed host lookup');
  }

  static String friendlyMessage(Object error) {
    if (isNetworkError(error)) return offlineMessage;

    if (error is Exception) {
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (msg.length > 10 && msg.length < 200) return msg;
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('invalid login') || raw.contains('invalid_credentials')) {
      return 'Código o contraseña incorrectos.';
    }
    if (raw.contains('rate limit') || raw.contains('429')) {
      return 'Demasiados intentos. Espere unos minutos.';
    }
    return 'No se pudo completar la operación.';
  }

  static Future<void> ensureSupabaseReachable() async {
    final host = Uri.parse(AppConfig.supabaseUrl).host;
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) throw Exception(offlineMessage);
    } on SocketException {
      throw Exception(offlineMessage);
    }
  }
}
