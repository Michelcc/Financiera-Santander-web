import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cartera_sync_helper.dart';
import 'database_helper.dart';
import '../core/network/api_client.dart';

class SupabaseService {
  SupabaseService._privateConstructor();
  static final SupabaseService instance = SupabaseService._privateConstructor();

  final SupabaseClient _client = Supabase.instance.client;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  String? _currentUserCode;
  String? _currentUserRole;
  String? _currentUserName;
  String? _currentAsesorId;

  String? get currentUserCode => _currentUserCode;
  String? get currentUserRole => _currentUserRole;
  String? get currentUserName => _currentUserName;
  String? get currentAsesorId => _currentAsesorId ?? currentUser?.id;

  void setAdvisorProfile(String code, String role, String name) {
    _currentUserCode = code;
    _currentUserRole = role;
    _currentUserName = name;
    _currentAsesorId = currentUser?.id;
  }

  Future<void> login(String code, String password, String selectedRole) async {
    final email = _mapCodeToEmail(code);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _currentUserCode = code;
      _currentAsesorId = response.user?.id;
      _currentUserRole =
          response.user?.userMetadata?['role'] as String? ?? selectedRole;
      _currentUserName = response.user?.userMetadata?['nombre'] as String? ??
          response.user?.userMetadata?['name'] as String? ??
          'Asesor ${code.toUpperCase()}';

      // Perfil asesor obligatorio para RLS de cartera
      if (response.user?.id != null) {
        await _client.from('perfiles_asesor').upsert({
          'id': response.user!.id,
          'nombre': _currentUserName,
          'codigo': code.toUpperCase(),
          'sucursal': 'Agencia Principal',
          'activo': true,
        });
      }

      await _client.auth.updateUser(
        UserAttributes(
          data: {
            'codigo': code.toUpperCase(),
            'role': _currentUserRole,
            'nombre': _currentUserName,
          },
        ),
      );

      await _loadAsesorProfile();
      await _resolveAsesorId();
    } catch (e) {
      debugPrint('Auth error: $e');
      rethrow;
    }
  }

  /// Tras restaurar sesión (cold start), preparar contexto de asesor.
  Future<void> ensureAdvisorContext() async {
    if (currentUser == null) return;
    await _loadAsesorProfile();
    await _resolveAsesorId();
  }

  Future<void> _loadAsesorProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return;

    try {
      final data = await _client
          .from('perfiles_asesor')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data != null) {
        _currentUserName = data['nombre'] as String? ?? _currentUserName;
        _currentUserCode = data['codigo'] as String? ?? _currentUserCode;
      }
    } catch (e) {
      debugPrint('Error cargando perfil asesor: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    _currentUserCode = null;
    _currentUserRole = null;
    _currentUserName = null;
    _currentAsesorId = null;
  }

  String _mapCodeToEmail(String code) {
    final clean = code.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return '$clean@asesor.santander.pe';
  }

  Future<String?> _resolveAsesorId() async {
    final uid = currentUser?.id;
    if (uid == null) return currentAsesorId;

    final codigo = (_currentUserCode ??
            currentUser?.userMetadata?['codigo'] ??
            'OP001')
        .toString()
        .toUpperCase();

    try {
      // Prioridad: perfil OP001/código (donde vive el seed de 31 clientes)
      final byCode = await _client
          .from('perfiles_asesor')
          .select('id, codigo')
          .ilike('codigo', codigo)
          .maybeSingle();

      if (byCode != null) {
        _currentAsesorId = byCode['id'] as String;
        _currentUserCode = byCode['codigo'] as String? ?? codigo;
        return _currentAsesorId;
      }

      final row = await _client
          .from('perfiles_asesor')
          .select('id, codigo')
          .eq('id', uid)
          .maybeSingle();

      if (row != null) {
        _currentAsesorId = uid;
        _currentUserCode = row['codigo'] as String? ?? codigo;
        return uid;
      }

      await _client.from('perfiles_asesor').upsert({
        'id': uid,
        'nombre': _currentUserName ?? 'Asesor $codigo',
        'codigo': codigo,
        'sucursal': 'Agencia Principal',
        'activo': true,
      });
      _currentAsesorId = uid;
    } catch (e) {
      debugPrint('Error resolviendo asesor_id: $e');
      _currentAsesorId = uid;
    }

    return _currentAsesorId;
  }

  Future<List<Map<String, dynamic>>> _fetchCarteraRpc() async {
    try {
      final data = await _client.rpc('get_mi_cartera');
      if (data is List && data.isNotEmpty) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('get_mi_cartera RPC: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchCarteraApi() async {
    try {
      final api = ApiClient.instance;
      final data = await api.get('/cartera');
      if (data is List && data.isNotEmpty) {
        return data.map((e) => _normalizeFromApi(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (e) {
      debugPrint('API /cartera: $e');
    }
    return [];
  }

  Map<String, dynamic> _normalizeFromApi(Map<String, dynamic> row) {
    return {
      'id': row['cliente_id'] ?? row['id'] ?? '',
      'documento': row['documento'] ?? '',
      'nombre': row['cliente_nombre'] ?? row['nombre'] ?? '',
      'telefono': row['telefono'] ?? '',
      'negocio_nombre': row['negocio_nombre'] ?? '',
      'negocio_tipo': row['negocio_tipo'] ?? 'Comercio',
      'direccion': row['direccion'] ?? '',
      'latitud': (row['latitud'] as num?)?.toDouble() ?? 0.0,
      'longitud': (row['longitud'] as num?)?.toDouble() ?? 0.0,
      'tipo_gestion': row['tipo_gestion'] ?? 'Renovacion',
      'prioridad': (row['prioridad'] as num?)?.toInt() ?? 3,
      'score_transaccional': (row['score_transaccional'] as num?)?.toInt() ?? 500,
      'score_campo': (row['score_campo'] as num?)?.toInt() ?? 0,
      'score_final': (row['score_final'] as num?)?.toInt() ?? 500,
      'hipotesis_credito': (row['hipotesis_credito'] as num?)?.toDouble() ?? 0,
      'segmento': row['segmento'] ?? 'ESTANDAR',
      'deuda_total': (row['deuda_total'] as num?)?.toDouble() ?? 0.0,
      'mora_dias': (row['mora_dias'] as num?)?.toInt() ?? 0,
      'ultimo_pago_fecha': row['ultimo_pago_fecha'] ?? '',
      'monto_preaprobado': (row['monto_preaprobado'] as num?)?.toDouble() ?? 0.0,
      'plazo_preaprobado': (row['plazo_preaprobado'] as num?)?.toInt() ?? 6,
      'tasa_preaprobada': (row['tasa_preaprobada'] as num?)?.toDouble() ?? 18.0,
      'historial_pagos': '[]',
    };
  }

  Future<void> _alinearCarteraConAsesor(String asesorId) async {
    try {
      await _client.rpc('reasignar_cartera_op001');
    } catch (e) {
      debugPrint('reasignar_cartera_op001: $e');
    }
    try {
      await _client.rpc('sync_todos_clientes_cartera');
    } catch (e) {
      debugPrint('sync_todos_clientes_cartera: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPortfolioRows() async {
    if (currentUser == null) {
      throw Exception('Sesión no activa. Inicie sesión con OP001.');
    }
    await ensureAdvisorContext();
    await downloadDailyPortfolio();
    if (_lastDownloadedRows.isEmpty) {
      throw Exception(
        'Cartera vacía tras sincronizar. Ejecute supabase_admin_cartera_final.sql '
        'en Supabase. auth=${currentUser?.id} asesor=$currentAsesorId',
      );
    }
    return _lastDownloadedRows;
  }

  List<Map<String, dynamic>> _lastDownloadedRows = [];

  Future<void> downloadDailyPortfolio() async {
    final asesorId = await _resolveAsesorId();
    if (asesorId == null) {
      throw Exception('Sin asesor autenticado. Cierre sesión e ingrese con OP001.');
    }

    try {
      await _alinearCarteraConAsesor(asesorId);

      var response = await _fetchCarteraRpc();

      if (response.isEmpty) {
        response = await _fetchCarteraApi();
      }

      if (response.isEmpty) {
        response = await _client
            .from('clientes')
            .select()
            .eq('asesor_id', asesorId)
            .order('prioridad');
      }

      if (response.isEmpty) {
        response = await _fetchClientesDesdeCarteraDiaria(asesorId);
      }

      if (response.isEmpty) {
        response = await _client
            .from('clientes')
            .select()
            .order('prioridad')
            .limit(100);
        debugPrint(
          'Fallback clientes sin filtro asesor: ${response.length} filas',
        );
      }

      if (response.isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        for (final row in response) {
          rows.add(_normalizeClienteRow(row));
        }
        _lastDownloadedRows = rows;
        await _db.clearTable('clientes');
        for (final row in rows) {
          await _db.insert('clientes', row);
        }
        debugPrint(
          'Cartera sincronizada: ${rows.length} clientes (asesor $asesorId)',
        );
        return;
      }

      _lastDownloadedRows = [];
      throw Exception(
        'Supabase devolvió 0 clientes. Ejecute supabase_admin_cartera_final.sql '
        'en Supabase. asesor=$asesorId auth=${currentUser?.id}',
      );
    } catch (e) {
      debugPrint('Error descargando cartera de Supabase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchClientesDesdeCarteraDiaria(
    String asesorId,
  ) async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T').first;
      final rows = await _client
          .from('cartera_diaria')
          .select('clientes(*)')
          .eq('asesor_id', asesorId)
          .eq('fecha_asignacion', hoy);

      final clientes = <Map<String, dynamic>>[];
      for (final row in rows) {
        final nested = row['clientes'];
        if (nested is Map<String, dynamic>) {
          clientes.add(nested);
        }
      }
      return clientes;
    } catch (e) {
      debugPrint('Error leyendo cartera_diaria: $e');
      return [];
    }
  }

  Map<String, dynamic> _normalizeClienteRow(Map<String, dynamic> row) {
    final historial = row['historial_pagos'];
    return {
      'id': row['id'],
      'documento': row['documento'] ?? '',
      'nombre': row['nombre'] ?? '',
      'telefono': row['telefono'] ?? '',
      'negocio_nombre': row['negocio_nombre'] ?? '',
      'negocio_tipo': row['negocio_tipo'] ?? '',
      'direccion': row['direccion'] ?? '',
      'latitud': (row['latitud'] as num?)?.toDouble() ?? 0.0,
      'longitud': (row['longitud'] as num?)?.toDouble() ?? 0.0,
      'tipo_gestion': row['tipo_gestion'] ?? 'Renovacion',
      'prioridad': (row['prioridad'] as num?)?.toInt() ?? 3,
      'score_transaccional':
          (row['score_transaccional'] as num?)?.toInt() ?? 500,
      'score_campo': (row['score_campo'] as num?)?.toInt() ?? 0,
      'score_final': (row['score_final'] as num?)?.toInt() ?? 500,
      'hipotesis_credito': (row['hipotesis_credito'] as num?)?.toDouble() ?? 0,
      'segmento': row['segmento'] ?? 'ESTANDAR',
      'deuda_total': (row['deuda_total'] as num?)?.toDouble() ?? 0.0,
      'mora_dias': (row['mora_dias'] as num?)?.toInt() ?? 0,
      'ultimo_pago_fecha': row['ultimo_pago_fecha'] ?? '',
      'monto_preaprobado':
          (row['monto_preaprobado'] as num?)?.toDouble() ?? 0.0,
      'plazo_preaprobado': (row['plazo_preaprobado'] as num?)?.toInt() ?? 6,
      'tasa_preaprobada': (row['tasa_preaprobada'] as num?)?.toDouble() ?? 18.0,
      'historial_pagos': historial is String
          ? historial
          : jsonEncode(historial ?? []),
    };
  }

  Future<String> uploadDocument(
    String applicationId,
    String fileType,
    String filePath,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('El archivo no existe en el path proporcionado.');
    }

    final uid = currentAsesorId ?? 'offline';
    final fileName =
        '${applicationId}_${fileType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = '$uid/$applicationId/$fileName';

    try {
      await _client.storage.from('expedientes').upload(storagePath, file);
      return _client.storage.from('expedientes').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Error subiendo archivo: $e');
      return 'file://$filePath';
    }
  }

  Future<Map<String, dynamic>> queryBureauAndRestrictions(
    String document,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'consultar-buro-mock',
        body: {
          'documento': document,
          'asesor_id': currentAsesorId,
          'consentimiento': true,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': true,
          'consent_verified': true,
          'rating_sbs': data['calificacion_sbs'] ?? 'Normal',
          'deuda_total_sbs': data['deuda_total_pen'] ?? 0,
          'mora_dias': data['dias_mayor_mora'] ?? 0,
          'restriccion': (data['calificacion_sbs'] == 'Perdida'),
          'motivo_restriccion': '',
          'aprobado_buro':
              data['calificacion_sbs'] == 'Normal' ||
              data['calificacion_sbs'] == 'CPP',
        };
      }
    } catch (e) {
      debugPrint('Edge function no disponible, usando simulador: $e');
    }

    await Future.delayed(const Duration(seconds: 1));

    final isBlacklisted =
        document.endsWith('999') || document == '00000000';
    if (isBlacklisted) {
      return {
        'success': true,
        'consent_verified': true,
        'rating_sbs': 'Perdida',
        'deuda_total_sbs': 15200.0,
        'mora_dias': 180,
        'restriccion': true,
        'motivo_restriccion':
            'Encontrado en lista de prevencion de fraude Santander',
        'aprobado_buro': false,
      };
    }

    final lastDigit =
        int.tryParse(document.substring(document.length - 1)) ?? 5;
    String rating = 'Normal';
    double debt = 0.0;
    int moraDays = 0;

    if (lastDigit == 3) {
      rating = 'CPP';
      debt = 2500.0;
      moraDays = 15;
    } else if (lastDigit == 7) {
      rating = 'Deficiente';
      debt = 8900.0;
      moraDays = 45;
    } else if (lastDigit == 0) {
      rating = 'Dudoso';
      debt = 12000.0;
      moraDays = 85;
    }

    return {
      'success': true,
      'consent_verified': true,
      'rating_sbs': rating,
      'deuda_total_sbs': debt,
      'mora_dias': moraDays,
      'restriccion': false,
      'motivo_restriccion': '',
      'aprobado_buro': rating == 'Normal' || rating == 'CPP',
    };
  }

  Future<bool> transmitSolicitud(Map<String, dynamic> solicitudData) async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return false;

    try {
      final payload = {
        'id': solicitudData['id'],
        'asesor_id': asesorId,
        'cliente_id': solicitudData['cliente_id'],
        'datos_personales': _parseJsonField(solicitudData['datos_personales']),
        'datos_negocio': _parseJsonField(solicitudData['datos_negocio']),
        'condiciones': _parseJsonField(solicitudData['condiciones']),
        'firma_path': solicitudData['firma_path'],
        'nitidez_ok': (solicitudData['nitidez_ok'] ?? 1) == 1,
        'fotos_paths': _parseJsonField(solicitudData['fotos_paths']),
        'score_campo': solicitudData['score_campo'] ?? 0,
        'score_final': solicitudData['score_final'] ?? 0,
        'segmento': solicitudData['segmento'] ?? 'BASICO',
        'monto_aprobado': solicitudData['monto_aprobado'] ?? 0,
        'plazo_aprobado': solicitudData['plazo_aprobado'] ?? 6,
        'cuota_mensual': solicitudData['cuota_mensual'] ?? 0,
        'estado': solicitudData['estado'] ?? 'Pendiente',
        'notas_asesor': solicitudData['notas_internas'],
      };

      await _client.from('solicitudes').upsert(payload);
      return true;
    } catch (e) {
      debugPrint('Error transmitiendo solicitud: $e');
      return false;
    }
  }

  Future<bool> syncVisita(Map<String, dynamic> visit) async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return false;

    try {
      await _client.from('visitas').upsert({
        'id': visit['id'],
        'asesor_id': asesorId,
        'cliente_id': visit['cliente_id'],
        'resultado': visit['resultado'],
        'observacion': visit['observacion'],
        'latitud': visit['latitud'],
        'longitud': visit['longitud'],
      });
      return true;
    } catch (e) {
      debugPrint('Error sincronizando visita: $e');
      return false;
    }
  }

  Future<bool> syncAccionCobranza(Map<String, dynamic> action) async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return false;

    try {
      await _client.from('acciones_cobranza').upsert({
        'id': action['id'],
        'asesor_id': asesorId,
        'cliente_id': action['cliente_id'],
        'tipo': action['tipo'],
        'observacion': action['observacion'],
        'compromiso_fecha': action['compromiso_fecha'],
        'compromiso_monto': action['compromiso_monto'],
        'latitud': action['latitud'],
        'longitud': action['longitud'],
      });
      return true;
    } catch (e) {
      debugPrint('Error sincronizando cobranza: $e');
      return false;
    }
  }

  Future<bool> syncProspecto(Map<String, dynamic> prospect) async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return false;

    try {
      await _client.from('prospectos').upsert({
        'id': prospect['id'] ?? 'pro_${prospect['documento']}',
        'asesor_id': asesorId,
        'documento': prospect['documento'],
        'nombre': prospect['nombre'],
        'telefono': prospect['telefono'],
        'negocio_nombre': prospect['negocio_nombre'],
        'ingresos': prospect['ingresos'],
        'pre_evaluacion': prospect['pre_evaluacion'],
        'motivo_desercion': prospect['motivo_desercion'],
        'latitud': prospect['latitud'],
        'longitud': prospect['longitud'],
      });
      await _upsertProspectoEnCartera(prospect, asesorId);
      return true;
    } catch (e) {
      debugPrint('Error sincronizando prospecto: $e');
      return false;
    }
  }

  Future<void> _upsertProspectoEnCartera(
    Map<String, dynamic> prospect,
    String asesorId,
  ) async {
    final doc = prospect['documento']?.toString() ?? '';
    if (doc.isEmpty) return;

    final clienteId = 'cli_$doc';
    final row = CarteraSyncHelper.fromProspect(prospect);

    await _client.from('clientes').upsert({
      'id': clienteId,
      'asesor_id': asesorId,
      'documento': row['documento'],
      'nombre': row['nombre'],
      'telefono': row['telefono'],
      'negocio_nombre': row['negocio_nombre'],
      'negocio_tipo': row['negocio_tipo'],
      'direccion': row['direccion'],
      'latitud': row['latitud'],
      'longitud': row['longitud'],
      'tipo_gestion': row['tipo_gestion'],
      'prioridad': row['prioridad'],
      'score_transaccional': row['score_transaccional'],
      'score_campo': row['score_campo'],
      'score_final': row['score_final'],
    }, onConflict: 'asesor_id,documento');

    final hoy = DateTime.now().toIso8601String().split('T').first;
    await _client.from('cartera_diaria').upsert({
      'asesor_id': asesorId,
      'cliente_id': clienteId,
      'fecha_asignacion': hoy,
      'tipo_gestion': 'Nueva Solicitud',
      'prioridad': 3,
      'score_prioridad': 50,
    }, onConflict: 'asesor_id,cliente_id,fecha_asignacion');
  }

  Future<void> upsertProspectoEnCarteraLocal(
    Map<String, dynamic> prospect,
  ) async {
    final row = CarteraSyncHelper.fromProspect(prospect);
    await _db.insert('clientes', row);
  }

  Future<bool> updateScoreCampo(String clienteId, int scoreCampo) async {
    try {
      await _client.from('clientes').update({
        'score_campo': scoreCampo,
      }).eq('id', clienteId);
      return true;
    } catch (e) {
      debugPrint('Error actualizando score_campo: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDeclaracionesInformales(
    String documento,
  ) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _client
            .from('declaraciones_informales')
            .select()
            .eq('documento', documento)
            .order('created_at', ascending: false),
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSolicitudes() async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return [];

    try {
      final response = await _client
          .from('solicitudes')
          .select()
          .eq('asesor_id', asesorId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error obteniendo solicitudes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotificaciones({
    required String role,
  }) async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return [];

    try {
      final isSupervisor = role == 'Supervisor' || role == 'Administrador';

      if (isSupervisor) {
        final response = await _client
            .from('notificaciones_supervisor')
            .select()
            .inFilter('audiencia', ['supervisor', 'todos'])
            .order('created_at', ascending: false)
            .limit(50);
        return List<Map<String, dynamic>>.from(response);
      }

      final response = await _client
          .from('notificaciones_supervisor')
          .select()
          .eq('asesor_id', asesorId)
          .inFilter('audiencia', ['asesor', 'todos'])
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error notificaciones: $e');
      return [];
    }
  }

  Future<int> contarNotificacionesNoLeidas({required String role}) async {
    final list = await fetchNotificaciones(role: role);
    return list.where((n) => n['leida'] != true).length;
  }

  Future<void> marcarNotificacionLeida(String id) async {
    await _client
        .from('notificaciones_supervisor')
        .update({'leida': true})
        .eq('id', id);
  }

  RealtimeChannel subscribeNotificaciones(void Function() onChange) {
    final uid = currentAsesorId ?? 'anon';
    return _client
        .channel('notif-sup-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_supervisor',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<Map<String, dynamic>> resolverSolicitud({
    required String solicitudId,
    required String decision,
    double? montoAprobado,
    int? plazo,
    String? motivo,
  }) async {
    final result = await _client.rpc('resolver_solicitud', params: {
      'p_solicitud_id': solicitudId,
      'p_decision': decision,
      'p_monto_aprobado': montoAprobado,
      'p_plazo': plazo,
      'p_motivo': motivo,
    });
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'ok': true};
  }

  Future<List<Map<String, dynamic>>> fetchVisitasHoy() async {
    final asesorId = currentAsesorId;
    if (asesorId == null) return [];
    final hoy = DateTime.now().toIso8601String().split('T').first;
    try {
      return List<Map<String, dynamic>>.from(
        await _client
            .from('visitas')
            .select('*, clientes(nombre, latitud, longitud)')
            .eq('asesor_id', asesorId)
            .gte('created_at', '${hoy}T00:00:00'),
      );
    } catch (e) {
      return [];
    }
  }

  dynamic _parseJsonField(dynamic value) {
    if (value == null) return {};
    if (value is Map || value is List) return value;
    try {
      return jsonDecode(value as String);
    } catch (_) {
      return value;
    }
  }

  List<Map<String, dynamic>> _generateMockPortfolio() {
    return [
      {
        'id': 'cli_001',
        'documento': '45781290',
        'nombre': 'Carlos Mendoza Prado',
        'telefono': '987654321',
        'negocio_nombre': 'Bodega Don Carlos',
        'negocio_tipo': 'Comercio / Venta de Abarrotes',
        'direccion': 'Av. Larco 452, Miraflores, Lima',
        'latitud': -12.1221,
        'longitud': -77.0298,
        'tipo_gestion': 'Renovacion',
        'prioridad': 2,
        'score_transaccional': 680,
        'deuda_total': 1200.0,
        'mora_dias': 0,
        'ultimo_pago_fecha': '2026-05-15',
        'monto_preaprobado': 3000.0,
        'plazo_preaprobado': 6,
        'tasa_preaprobada': 15.5,
        'historial_pagos': '[350, 350, 350, 350, 350, 350, 0, 0, 0, 0, 0, 0]',
      },
      {
        'id': 'cli_002',
        'documento': '10473922',
        'nombre': 'Juana Flores Ruiz',
        'telefono': '945612307',
        'negocio_nombre': 'Lenceria & Confecciones Juana',
        'negocio_tipo': 'Produccion / Textil',
        'direccion': 'Jr. Gamarra 820, La Victoria, Lima',
        'latitud': -12.0628,
        'longitud': -77.0151,
        'tipo_gestion': 'Ampliacion',
        'prioridad': 3,
        'score_transaccional': 760,
        'deuda_total': 400.0,
        'mora_dias': 0,
        'ultimo_pago_fecha': '2026-05-20',
        'monto_preaprobado': 4500.0,
        'plazo_preaprobado': 12,
        'tasa_preaprobada': 12.0,
        'historial_pagos':
            '[400, 400, 400, 400, 400, 400, 400, 400, 400, 400, 400, 400]',
      },
      {
        'id': 'cli_003',
        'documento': '73920199',
        'nombre': 'Maria Quispe Mamani',
        'telefono': '912345678',
        'negocio_nombre': 'Frutas y Verduras Maria',
        'negocio_tipo': 'Comercio / Puesto de Mercado',
        'direccion': 'Mercado Surco Nro 3, Santiago de Surco',
        'latitud': -12.1472,
        'longitud': -77.0211,
        'tipo_gestion': 'Mora',
        'prioridad': 1,
        'score_transaccional': 490,
        'deuda_total': 2100.0,
        'mora_dias': 35,
        'ultimo_pago_fecha': '2026-04-10',
        'monto_preaprobado': 1500.0,
        'plazo_preaprobado': 3,
        'tasa_preaprobada': 18.0,
        'historial_pagos': '[500, 500, 500, 500, 0, 0, 0, 0, 0, 0, 0, 0]',
      },
      {
        'id': 'cli_004',
        'documento': '09283471',
        'nombre': 'Roberto Gomez Silva',
        'telefono': '993847291',
        'negocio_nombre': 'Carpinteria Gomez',
        'negocio_tipo': 'Servicios / Carpinteria',
        'direccion': 'Av. Separadora Industrial 1250, Ate, Lima',
        'latitud': -12.0722,
        'longitud': -76.9535,
        'tipo_gestion': 'Renovacion',
        'prioridad': 4,
        'score_transaccional': 590,
        'deuda_total': 320.0,
        'mora_dias': 0,
        'ultimo_pago_fecha': '2026-05-28',
        'monto_preaprobado': 2000.0,
        'plazo_preaprobado': 6,
        'tasa_preaprobada': 16.0,
        'historial_pagos': '[200, 200, 200, 200, 200, 200, 200, 200, 0, 0, 0, 0]',
      },
      {
        'id': 'cli_005',
        'documento': '41203948',
        'nombre': 'Elena Palacios Vega',
        'telefono': '951239847',
        'negocio_nombre': 'Salon de Belleza Elena',
        'negocio_tipo': 'Servicios / Estetica',
        'direccion': 'Calle Cantuarias 140, Miraflores, Lima',
        'latitud': -12.1212,
        'longitud': -77.0289,
        'tipo_gestion': 'Mora',
        'prioridad': 1,
        'score_transaccional': 320,
        'deuda_total': 3800.0,
        'mora_dias': 72,
        'ultimo_pago_fecha': '2026-03-05',
        'monto_preaprobado': 800.0,
        'plazo_preaprobado': 3,
        'tasa_preaprobada': 20.0,
        'historial_pagos': '[600, 600, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]',
      },
    ];
  }
}
