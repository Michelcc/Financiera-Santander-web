import '../core/network/api_client.dart';
import '../models/perfil_cliente_model.dart';
import '../models/credito_api_model.dart';
import '../models/cuenta_ahorro_model.dart';
import '../models/movimiento_model.dart';
import '../models/tarjeta_model.dart';
import '../models/notificacion_api_model.dart';

/// Servicio que consume los endpoints /cliente/* del backend FastAPI.
/// Reemplaza a ClienteSupabaseService para toda la lógica de datos.
class ClienteApiService {
  ClienteApiService._();
  static final ClienteApiService instance = ClienteApiService._();

  final _api = ApiClient.instance;

  // ── Auth ───────────────────────────────────────────────────────
  /// Login con DNI + contraseña → guarda JWT y devuelve el perfil.
  Future<PerfilClienteModel> login(String documento, String password) async {
    final data = await _api.post(
      '/cliente/login',
      {'numero_documento': documento, 'password': password},
      auth: false,
    );
    await _api.saveToken(data['access_token'] as String);
    return PerfilClienteModel.fromApiMap(data['cliente'] as Map<String, dynamic>);
  }

  /// Restaura la sesión si hay token guardado.
  Future<PerfilClienteModel?> restoreSession() async {
    final token = await _api.getToken();
    if (token == null) return null;
    try {
      final data = await _api.get('/cliente/perfil');
      return PerfilClienteModel.fromApiMap(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
      return null;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
  }

  // ── Perfil ─────────────────────────────────────────────────────
  Future<PerfilClienteModel?> getPerfil() async {
    try {
      final data = await _api.get('/cliente/perfil');
      return PerfilClienteModel.fromApiMap(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Cuentas de ahorro ──────────────────────────────────────────
  Future<List<CuentaAhorroModel>> getCuentas() async {
    try {
      final data = await _api.get('/cliente/cuentas') as List;
      return data
          .map((e) => CuentaAhorroModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Créditos ───────────────────────────────────────────────────
  Future<List<CreditoApiModel>> getCreditos() async {
    try {
      final data = await _api.get('/cliente/creditos') as List;
      return data
          .map((e) => CreditoApiModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCronograma(String codCuenta) async {
    try {
      final data = await _api.get('/cliente/creditos/$codCuenta/cronograma') as List;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Movimientos ────────────────────────────────────────────────
  Future<List<MovimientoModel>> getMovimientos({int limit = 20}) async {
    try {
      final data = await _api.get('/cliente/movimientos?limit=$limit') as List;
      return data
          .map((e) => MovimientoModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Tarjetas ───────────────────────────────────────────────────
  Future<List<TarjetaModel>> getTarjetas() async {
    try {
      final data = await _api.get('/cliente/tarjetas') as List;
      return data
          .map((e) => TarjetaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Notificaciones ─────────────────────────────────────────────
  Future<List<NotificacionApiModel>> getNotificaciones() async {
    try {
      final data = await _api.get('/cliente/notificaciones') as List;
      return data
          .map((e) => NotificacionApiModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Operaciones ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> crearOperacion({
    required String codCuentaOrigen,
    String? codCuentaDestino,
    required String tipo,
    required double monto,
    String moneda = 'PEN',
  }) async {
    try {
      final data = await _api.post('/cliente/operaciones', {
        'cod_cuenta_origen': codCuentaOrigen,
        if (codCuentaDestino != null) 'cod_cuenta_destino': codCuentaDestino,
        'tipo': tipo,
        'monto': monto,
        'moneda': moneda,
      });
      return data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
