import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asesor_model.dart';
import '../models/auth_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/cartera_repository.dart';

class AuthState {
  AuthState({
    this.status = AuthStatus.idle,
    this.asesor,
    this.error,
  });

  final AuthStatus status;
  final AsesorModel? asesor;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  String? get advisorCode => asesor?.codigo;
  String? get advisorName => asesor?.nombre;
  String get role => asesor?.rol ?? 'Operador';

  AuthState copyWith({
    AuthStatus? status,
    AsesorModel? asesor,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      asesor: asesor ?? this.asesor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._auth) : super(AuthState()) {
    _restore();
  }

  final AuthRepository _auth;

  Future<void> _restore() async {
    final result = await _auth.restoreSession();
    if (result.status != AuthStatus.authenticated || result.asesor == null) {
      return;
    }

    state = AuthState(
      status: AuthStatus.authenticated,
      asesor: result.asesor,
    );
  }

  Future<bool> login(String code, String password, String selectedRole) async {
    if (state.status == AuthStatus.bloqueado) {
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    final result = await _auth.login(code, password, selectedRole);

    if (result.success && result.asesor != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        asesor: result.asesor,
      );
      return true;
    }

    state = AuthState(
      status: result.status,
      error: result.error,
    );
    return false;
  }

  Future<bool> hasPendingDrafts() async {
    final count = await _auth.pendingSyncCount();
    return count > 0;
  }

  Future<void> logout({bool force = false}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _auth.logout(force: force);
      state = AuthState();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final carteraRepositoryProvider = Provider<CarteraRepository>((ref) {
  return CarteraRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
