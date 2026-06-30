import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/network_helper.dart';
import '../models/cliente_score_model.dart';
import '../models/credito_model.dart';
import '../models/cuenta_ahorro_model.dart';
import '../models/movimiento_model.dart';
import '../models/tarjeta_model.dart';
import '../models/notificacion_model.dart';
import '../models/perfil_cliente_model.dart';
import '../models/solicitud_model.dart';

class ClienteSupabaseService {
  ClienteSupabaseService._();
  static final ClienteSupabaseService instance = ClienteSupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  /// Acepta DNI (45781290) o correo interno (45781290@cliente.santander.pe).
  String normalizeDocumento(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed.split('@').first.trim();
    }
    return trimmed;
  }

  String mapDocumentoToEmail(String documento) =>
      '${normalizeDocumento(documento)}@cliente.santander.pe';

  Future<void> login(String documento, String password) async {
    await NetworkHelper.ensureSupabaseReachable();
    final dni = normalizeDocumento(documento);
    if (dni.isEmpty) {
      throw Exception('Ingrese su DNI');
    }
    await _client.auth.signInWithPassword(
      email: mapDocumentoToEmail(dni),
      password: password,
    );
  }

  String _generarNumeroCuenta(String dni) {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    return 'SCF-${dni.substring(0, 4)}${suffix.substring(suffix.length - 4)}';
  }

  Future<PerfilClienteModel> registerCliente({
    required String nombre,
    required String documento,
    required String telefono,
    required String password,
  }) async {
    await NetworkHelper.ensureSupabaseReachable();
    final dni = normalizeDocumento(documento);
    if (dni.isEmpty) throw Exception('Ingrese su DNI');
    if (dni.length != 8) throw Exception('El DNI debe tener 8 dígitos');

    final email = mapDocumentoToEmail(dni);

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': 'cliente',
        'nombre': nombre,
        'documento': dni,
        'telefono': telefono,
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception(
        'No se pudo registrar. Verifique que el DNI no esté en uso.',
      );
    }

    if (user.identities != null && user.identities!.isEmpty) {
      throw Exception(
        'Este DNI ya tiene cuenta. Use Iniciar sesión con su DNI y contraseña.',
      );
    }

    if (response.session == null) {
      try {
        await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (_) {
        throw Exception(
          'Cuenta creada, pero Supabase pide confirmar el correo. '
          'Desactive "Confirm email" en Authentication → Providers → Email '
          'o marque el usuario como confirmado en el panel.',
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    var perfil = await getPerfilCliente();

    if (perfil == null && currentUser != null) {
      try {
        await _client.from('perfiles_cliente').insert({
          'id': currentUser!.id,
          'nombre': nombre,
          'documento': dni,
          'telefono': telefono,
          'email': email,
          'numero_cuenta': _generarNumeroCuenta(dni),
        });
        perfil = await getPerfilCliente();
      } catch (e) {
        debugPrint('Insert perfil fallback: $e');
      }
    }

    if (perfil != null) {
      await _syncPerfilACartera(dni);
      return perfil;
    }
    throw Exception(
      'Usuario creado pero falta el perfil. Ejecute supabase_completo.sql '
      'en Supabase (trigger handle_new_user).',
    );
  }

  /// Crea/actualiza el cliente en la cartera del asesor (tabla clientes).
  Future<void> _syncPerfilACartera(String documento) async {
    try {
      await _client.rpc('sync_perfil_cliente_cartera', params: {
        'p_documento': documento,
      });
    } catch (e) {
      debugPrint('Sync perfil a cartera: $e');
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<PerfilClienteModel?> getPerfilCliente() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final data = await _client
          .from('perfiles_cliente')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data == null) return null;
      return PerfilClienteModel.fromMap(data);
    } catch (e) {
      debugPrint('Error perfil cliente: $e');
      return null;
    }
  }

  Future<ClienteScoreModel?> getClienteScores() async {
    final perfil = await getPerfilCliente();
    if (perfil == null) return null;

    try {
      final data = await _client
          .from('clientes')
          .select()
          .eq('documento', perfil.documento)
          .maybeSingle();

      if (data != null) return ClienteScoreModel.fromMap(data);
    } catch (e) {
      debugPrint('Error scores cliente: $e');
    }

    return null;
  }

  RealtimeChannel subscribeToScores(
    String documento,
    void Function(ClienteScoreModel) onUpdate,
  ) {
    return _client
        .channel('cliente-scores-$documento')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'clientes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'documento',
            value: documento,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onUpdate(ClienteScoreModel.fromMap(record));
            }
          },
        )
        .subscribe();
  }

  Future<List<CreditoModel>> getCreditos() async {
    final uid = currentUser?.id;
    if (uid == null) return [];

    try {
      final rows = await _client
          .from('creditos')
          .select()
          .or('cliente_user_id.eq.$uid')
          .order('created_at', ascending: false);

      final creditos = <CreditoModel>[];
      for (final row in rows) {
        final credito = CreditoModel.fromMap(row);
        final pagos = await _client
            .from('pagos_credito')
            .select()
            .eq('credito_id', credito.id)
            .order('numero_cuota');
        creditos.add(CreditoModel(
          id: credito.id,
          monto: credito.monto,
          plazoMeses: credito.plazoMeses,
          tea: credito.tea,
          cuotaMensual: credito.cuotaMensual,
          saldoPendiente: credito.saldoPendiente,
          estado: credito.estado,
          fechaDesembolso: credito.fechaDesembolso,
          fechaVencimiento: credito.fechaVencimiento,
          diasMora: credito.diasMora,
          pagos: pagos
              .map((p) => PagoCreditoModel.fromMap(p))
              .toList(),
        ));
      }
      return creditos;
    } catch (e) {
      debugPrint('Error creditos: $e');
      rethrow;
    }
  }

  /// Registra solicitud real en Supabase (RPC + alertas asesor/supervisor).
  Future<Map<String, dynamic>> crearSolicitud({
    required double monto,
    required int plazoMeses,
    String destino = 'Capital de trabajo',
    bool conSeguro = false,
  }) async {
    await NetworkHelper.ensureSupabaseReachable();
    final perfil = await getPerfilCliente();
    if (perfil == null) {
      throw Exception('Complete su perfil antes de solicitar crédito.');
    }

    final result = await _client.rpc('crear_solicitud_desde_cliente', params: {
      'p_monto': monto,
      'p_plazo': plazoMeses,
      'p_destino': destino,
      'p_con_seguro': conSeguro,
    }).catchError((_) => null);

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    return _crearSolicitudDirecta(
      perfil: perfil,
      monto: monto,
      plazoMeses: plazoMeses,
      destino: destino,
      conSeguro: conSeguro,
    );
  }

  Future<Map<String, dynamic>> _crearSolicitudDirecta({
    required PerfilClienteModel perfil,
    required double monto,
    required int plazoMeses,
    required String destino,
    required bool conSeguro,
  }) async {
    final uid = currentUser!.id;
    final tea = conSeguro ? 40.92 : 43.92;
    final tep = pow(1 + tea / 100, 1 / 12) - 1;
    final factor = pow(1 + tep, plazoMeses);
    final cuota = tep == 0
        ? monto / plazoMeses
        : monto * (tep * factor) / (factor - 1);

    try {
      await _client.rpc('sync_perfil_cliente_cartera', params: {
        'p_documento': perfil.documento,
      });
    } catch (_) {}

    String? asesorId;
    try {
      final perfilRow = await _client
          .from('perfiles_cliente')
          .select('asesor_id')
          .eq('id', uid)
          .maybeSingle();
      asesorId = perfilRow?['asesor_id']?.toString();
    } catch (_) {}

    if (asesorId == null || asesorId.isEmpty) {
      final def = await _client.rpc('get_default_asesor_id');
      if (def != null) asesorId = def.toString();
    }

    if (asesorId == null || asesorId.isEmpty) {
      throw Exception(
        'No hay asesor asignado. Ejecute supabase_reparar_rapido.sql en Supabase.',
      );
    }

    final solId =
        'sol_cli_${perfil.documento}_${DateTime.now().millisecondsSinceEpoch}';
    final exp =
        'EXP-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final clienteId = 'cli_${perfil.documento}';

    await _client.from('solicitudes').insert({
      'id': solId,
      'asesor_id': asesorId,
      'cliente_id': clienteId,
      'cliente_user_id': uid,
      'documento_cliente': perfil.documento,
      'datos_personales': {
        'nombre': perfil.nombre,
        'documento': perfil.documento,
        'origen': 'app_cliente',
      },
      'condiciones': {
        'monto': monto,
        'plazo': plazoMeses,
        'destino': destino,
        'tea': tea,
        'con_seguro': conSeguro,
      },
      'estado': 'Enviado',
      'cuota_mensual': double.parse(cuota.toStringAsFixed(2)),
      'plazo_aprobado': plazoMeses,
      'expediente_numero': exp,
      'timeline': [
        {
          'estado': 'Enviado',
          'fecha': DateTime.now().toUtc().toIso8601String(),
          'descripcion': 'Solicitud registrada (modo directo)',
        },
      ],
    });

    return {
      'id': solId,
      'expediente_numero': exp,
      'cuota_mensual': double.parse(cuota.toStringAsFixed(2)),
      'estado': 'Enviado',
    };
  }

  Future<List<SolicitudModel>> getSolicitudes() async {
    final uid = currentUser?.id;
    final perfil = await getPerfilCliente();
    if (uid == null) return [];

    try {
      final rows = await _client
          .from('solicitudes')
          .select()
          .or(
            'cliente_user_id.eq.$uid,documento_cliente.eq.${perfil?.documento ?? ''}',
          )
          .order('created_at', ascending: false);
      return rows.map((r) => SolicitudModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error solicitudes: $e');
      return [];
    }
  }

  RealtimeChannel subscribeToSolicitudes(void Function() onChange) {
    final uid = currentUser?.id ?? 'anon';
    return _client
        .channel('mis-solicitudes-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'solicitudes',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> declararDeudaInformal({
    required bool tieneDeuda,
    required double monto,
    required String entidad,
  }) async {
    final uid = currentUser?.id;
    final perfil = await getPerfilCliente();
    if (uid == null || perfil == null) return;

    await _client.from('declaraciones_informales').insert({
      'cliente_user_id': uid,
      'documento': perfil.documento,
      'tiene_deuda': tieneDeuda,
      'monto_aproximado': monto,
      'entidad': entidad,
    });
  }

  Future<List<Map<String, dynamic>>> getDeclaraciones() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        await _client
            .from('declaraciones_informales')
            .select()
            .eq('cliente_user_id', uid)
            .order('created_at', ascending: false),
      );
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMiAsesor() async {
    final perfil = await getPerfilCliente();
    if (perfil == null) return null;

    try {
      final perfilData = await _client
          .from('perfiles_cliente')
          .select('asesor_id')
          .eq('id', perfil.id)
          .maybeSingle();

      final asesorId = perfilData?['asesor_id'];
      if (asesorId == null) return null;

      final asesor = await _client
          .from('perfiles_asesor')
          .select()
          .eq('id', asesorId)
          .maybeSingle();
      return asesor;
    } catch (e) {
      debugPrint('Error asesor: $e');
      return null;
    }
  }

  Future<List<NotificacionModel>> getNotificaciones() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('notificaciones_cliente')
          .select()
          .eq('cliente_user_id', uid)
          .order('created_at', ascending: false);
      return rows.map((r) => NotificacionModel.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> marcarNotificacionLeida(String id) async {
    await _client
        .from('notificaciones_cliente')
        .update({'leida': true})
        .eq('id', id);
  }

  Future<void> _ensureProductos() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await _client.rpc('ensure_productos_cliente', params: {'p_user_id': uid});
    } catch (e) {
      debugPrint('ensure_productos_cliente: $e');
    }
  }

  Future<List<CuentaAhorroModel>> getCuentas() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    await _ensureProductos();
    try {
      final rows = await _client
          .from('cuentas_ahorro')
          .select()
          .eq('cliente_user_id', uid)
          .order('created_at');
      final list = rows
          .map((r) => CuentaAhorroModel.fromMap(r))
          .toList();
      if (list.isNotEmpty) return list;

      final perfil = await getPerfilCliente();
      if (perfil != null && perfil.numeroCuenta.isNotEmpty) {
        return [
          CuentaAhorroModel(
            id: 'cuenta_${perfil.documento}',
            codCuentaAhorro: perfil.numeroCuenta,
            saldoCapital: 0,
            estado: 'activa',
            tipoCuenta: 'ahorro',
            moneda: 'PEN',
          ),
        ];
      }
      return [];
    } catch (e) {
      debugPrint('Error cuentas: $e');
      final perfil = await getPerfilCliente();
      if (perfil != null && perfil.numeroCuenta.isNotEmpty) {
        return [
          CuentaAhorroModel(
            id: 'cuenta_${perfil.documento}',
            codCuentaAhorro: perfil.numeroCuenta,
            saldoCapital: 0,
            estado: 'activa',
            tipoCuenta: 'ahorro',
            moneda: 'PEN',
          ),
        ];
      }
      return [];
    }
  }

  Future<List<TarjetaModel>> getTarjetas() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    await _ensureProductos();
    try {
      final rows = await _client
          .from('tarjetas_cliente')
          .select()
          .eq('cliente_user_id', uid);
      return rows.map((r) => TarjetaModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error tarjetas: $e');
      return [];
    }
  }

  Future<List<MovimientoModel>> getMovimientos({int limit = 30}) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    await _ensureProductos();
    try {
      final rows = await _client
          .from('movimientos_cliente')
          .select()
          .eq('cliente_user_id', uid)
          .order('fecha_operacion', ascending: false)
          .limit(limit);
      return rows.map((r) => MovimientoModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error movimientos: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> registrarOperacion({
    required String codCuentaOrigen,
    String? codCuentaDestino,
    required String tipo,
    required double monto,
    String? concepto,
  }) async {
    await NetworkHelper.ensureSupabaseReachable();
    final result = await _client.rpc('registrar_operacion_cliente', params: {
      'p_cod_cuenta_origen': codCuentaOrigen,
      'p_cod_cuenta_destino': codCuentaDestino ?? codCuentaOrigen,
      'p_tipo': tipo,
      'p_monto': monto,
      'p_concepto': concepto,
    });
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'ok': true};
  }

  Future<void> actualizarPerfil({String? nombre, String? telefono}) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (nombre != null && nombre.trim().isNotEmpty) {
      updates['nombre'] = nombre.trim();
    }
    if (telefono != null && telefono.trim().isNotEmpty) {
      updates['telefono'] = telefono.trim();
    }
    if (updates.isEmpty) return;
    await _client.from('perfiles_cliente').update(updates).eq('id', uid);
  }

  RealtimeChannel subscribeToNotificaciones(void Function() onChange) {
    final uid = currentUser?.id ?? 'anon';
    return _client
        .channel('notif-cliente-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_cliente',
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
