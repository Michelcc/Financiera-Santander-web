import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/network_helper.dart';
import '../models/perfil_cliente_model.dart';
import '../services/cliente_supabase_service.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.perfil,
    this.isLoading = false,
    this.error,
  });

  final bool isAuthenticated;
  final PerfilClienteModel? perfil;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    bool? isAuthenticated,
    PerfilClienteModel? perfil,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      perfil: perfil ?? this.perfil,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restoreSession();
  }

  final _service = ClienteSupabaseService.instance;

  Future<void> _restoreSession() async {
    if (_service.currentSession == null) return;
    state = state.copyWith(isLoading: true);
    final perfil = await _service.getPerfilCliente();
    state = AuthState(
      isAuthenticated: perfil != null,
      perfil: perfil,
      isLoading: false,
    );
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();

    if (NetworkHelper.isNetworkError(error)) {
      return NetworkHelper.friendlyNetworkMessage();
    }

    if (error is Exception) {
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (msg != error.toString() &&
          msg.length > 10 &&
          msg.length < 120 &&
          !msg.contains('authapi') &&
          !msg.contains('clientexception')) {
        return msg;
      }
    }

    final apiMsg = RegExp(r'message:\s*([^,]+)', caseSensitive: false)
        .firstMatch(raw)
        ?.group(1)
        ?.trim()
        .toLowerCase();

    if (raw.contains('rate limit') ||
        raw.contains('over_email_send_rate_limit') ||
        apiMsg?.contains('rate limit') == true ||
        raw.contains('statuscode: 429')) {
      return 'Demasiados intentos de registro. Espere 30-60 minutos o desactive '
          '"Confirm email" en Supabase → Authentication → Providers → Email.';
    }
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'DNI o contraseña incorrectos.';
    }
    if (raw.contains('email not confirmed') ||
        raw.contains('email_not_confirmed')) {
      return 'Cuenta sin confirmar. Desactive "Confirm email" en Supabase '
          'o confirme el usuario manualmente.';
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered') ||
        raw.contains('already registered') ||
        apiMsg?.contains('already') == true) {
      return 'Este DNI ya tiene cuenta. Use Iniciar sesión.';
    }
    if (raw.contains('password') &&
        (raw.contains('weak') ||
            raw.contains('short') ||
            raw.contains('at least'))) {
      return 'Contraseña muy débil. Use mínimo 6 caracteres.';
    }
    if (raw.contains('signup') && raw.contains('disabled')) {
      return 'Registro deshabilitado en Supabase. Active sign-ups en Authentication.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('timed out')) {
      return NetworkHelper.friendlyNetworkMessage();
    }
    if (raw.contains('no se pudo crear el perfil') ||
        raw.contains('falta el perfil')) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return 'No se pudo completar la operación. Intente nuevamente.';
  }

  Future<bool> login(String documento, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.login(documento, password);
      final perfil = await _service.getPerfilCliente();
      if (perfil == null) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Sesión iniciada, pero falta su perfil en Supabase. '
              'Ejecute supabase_completo.sql o cree el usuario demo.',
        );
        await _service.logout();
        return false;
      }
      state = AuthState(isAuthenticated: true, perfil: perfil);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyAuthError(e));
      return false;
    }
  }

  Future<PerfilClienteModel?> register({
    required String nombre,
    required String documento,
    required String telefono,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final perfil = await _service.registerCliente(
        nombre: nombre,
        documento: documento,
        telefono: telefono,
        password: password,
      );
      state = AuthState(isAuthenticated: true, perfil: perfil);
      return perfil;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyAuthError(e));
      return null;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
