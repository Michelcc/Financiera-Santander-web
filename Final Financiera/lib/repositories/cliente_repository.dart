import '../models/cuenta_ahorro_model.dart';
import '../models/movimiento_model.dart';
import '../models/notificacion_model.dart';
import '../models/perfil_cliente_model.dart';
import '../models/tarjeta_model.dart';
import '../services/cliente_api_service.dart';
import '../services/cliente_supabase_service.dart';

/// Repositorio unificado — FastAPI primero, Supabase como respaldo (guía AppMiBanco).
class ClienteRepository {
  ClienteRepository._();
  static final ClienteRepository instance = ClienteRepository._();

  final _api = ClienteApiService.instance;
  final _supabase = ClienteSupabaseService.instance;

  Future<List<CuentaAhorroModel>> getCuentas() async {
    try {
      final list = await _api.getCuentas();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return _supabase.getCuentas();
  }

  Future<List<TarjetaModel>> getTarjetas() async {
    try {
      final list = await _api.getTarjetas();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return _supabase.getTarjetas();
  }

  Future<List<MovimientoModel>> getMovimientos({int limit = 30}) async {
    try {
      final list = await _api.getMovimientos(limit: limit);
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return _supabase.getMovimientos(limit: limit);
  }

  Future<List<NotificacionModel>> getNotificaciones() async {
    try {
      final apiList = await _api.getNotificaciones();
      if (apiList.isNotEmpty) {
        return apiList
            .map(
              (n) => NotificacionModel(
                id: n.id,
                tipo: n.tipo ?? 'info',
                titulo: n.titulo,
                mensaje: n.cuerpo ?? '',
                leida: n.leida,
                createdAt: n.createdAt,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return _supabase.getNotificaciones();
  }

  Future<Map<String, dynamic>?> registrarOperacion({
    required String codCuentaOrigen,
    String? codCuentaDestino,
    required String tipo,
    required double monto,
    String? concepto,
  }) async {
    try {
      final res = await _api.crearOperacion(
        codCuentaOrigen: codCuentaOrigen,
        codCuentaDestino: codCuentaDestino,
        tipo: tipo,
        monto: monto,
      );
      if (res != null) return res;
    } catch (_) {}
    return _supabase.registrarOperacion(
      codCuentaOrigen: codCuentaOrigen,
      codCuentaDestino: codCuentaDestino,
      tipo: tipo,
      monto: monto,
      concepto: concepto,
    );
  }

  Future<PerfilClienteModel?> getPerfil() async {
    try {
      final p = await _api.getPerfil();
      if (p != null) return p;
    } catch (_) {}
    return _supabase.getPerfilCliente();
  }

  Future<void> actualizarPerfil({String? nombre, String? telefono}) =>
      _supabase.actualizarPerfil(nombre: nombre, telefono: telefono);

  Future<void> marcarNotificacionLeida(String id) =>
      _supabase.marcarNotificacionLeida(id);
}
