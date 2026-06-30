import 'dart:io';

import '../../src/core/app_config.dart';

class NetworkHelper {
  static const _offlineMessage =
      'Sin conexión a internet. Active WiFi o datos móviles, '
      'desactive modo avión y vuelva a intentar.';

  static bool isNetworkError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('host lookup') ||
        raw.contains('socketfailed') ||
        raw.contains('no address associated with hostname') ||
        raw.contains('authretryablefetchexception') ||
        raw.contains('clientexception') ||
        raw.contains('errno = 7') ||
        raw.contains('network is unreachable') ||
        raw.contains('failed host lookup');
  }

  static String friendlyNetworkMessage() => _offlineMessage;

  /// Verifica DNS + HTTPS hacia Supabase antes de login/registro.
  static Future<void> ensureSupabaseReachable() async {
    final host = Uri.parse(AppConfig.supabaseUrl).host;

    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        throw Exception(_offlineMessage);
      }
    } on SocketException {
      throw Exception(_offlineMessage);
    }

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(
        Uri.parse('${AppConfig.supabaseUrl}/auth/v1/health'),
      );
      request.followRedirects = false;
      await request.close().timeout(const Duration(seconds: 8));
      client.close(force: true);
    } on SocketException {
      throw Exception(_offlineMessage);
    } on HandshakeException {
      throw Exception(
        'Error de conexión segura con el servidor. Revise fecha/hora del teléfono.',
      );
    } catch (_) {
      // Health puede responder distinto; si DNS OK, dejamos continuar.
    }
  }
}
