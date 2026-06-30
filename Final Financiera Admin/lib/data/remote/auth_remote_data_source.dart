import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import '../../models/asesor_model.dart';
import '../../services/supabase_service.dart';

/// Autenticación remota (UML: AuthRemoteDataSource).
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    SupabaseService? supabase,
    ApiClient? api,
  })  : _supabase = supabase ?? SupabaseService.instance,
        _api = api ?? ApiClient.instance;

  final SupabaseService _supabase;
  final ApiClient _api;

  static const _asesorKey = 'auth_asesor';

  Session? get currentSession => _supabase.currentSession;

  Future<AsesorModel> login(
    String code,
    String password,
    String selectedRole,
  ) async {
    await _supabase.login(code, password, selectedRole);

    final asesor = AsesorModel(
      id: _supabase.currentAsesorId ?? '',
      codigo: code.toUpperCase(),
      nombre: _supabase.currentUserName ?? 'Asesor ${code.toUpperCase()}',
      rol: _supabase.currentUserRole ?? selectedRole,
    );

    final token = _supabase.currentSession?.accessToken;
    if (token != null) await _api.saveToken(token);

    await _persistAsesor(asesor);
    return asesor;
  }

  Future<AsesorModel?> restoreSession() async {
    final session = currentSession;
    if (session == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_asesorKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final asesor = AsesorModel.fromMap(map);
        _supabase.setAdvisorProfile(
          asesor.codigo,
          asesor.rol,
          asesor.nombre,
        );
        await _supabase.ensureAdvisorContext();
        return asesor;
      } catch (_) {}
    }

    final email = session.user.email ?? '';
    final code = email.split('@').first.toUpperCase();
    final role =
        (session.user.userMetadata?['role'] ?? 'Operador') as String;
    final name = session.user.userMetadata?['nombre'] ??
        session.user.userMetadata?['name'] ??
        'Asesor $code';

    _supabase.setAdvisorProfile(code, role, name);
    await _supabase.ensureAdvisorContext();

    final asesor = AsesorModel(
      id: _supabase.currentAsesorId ?? session.user.id,
      codigo: code,
      nombre: name,
      rol: role,
    );
    await _persistAsesor(asesor);
    return asesor;
  }

  Future<void> logout() async {
    await _supabase.logout();
    await _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_asesorKey);
  }

  Future<void> _persistAsesor(AsesorModel asesor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_asesorKey, jsonEncode(asesor.toMap()));
  }
}
