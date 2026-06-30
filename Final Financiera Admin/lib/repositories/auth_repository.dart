import 'package:shared_preferences/shared_preferences.dart';

import '../data/remote/auth_remote_data_source.dart';
import '../../core/utils/network_helper.dart';
import '../../models/asesor_model.dart';
import '../../models/auth_status.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';

/// Orquestador de autenticación (UML: AuthRepository).
class AuthRepository {
  AuthRepository({
    AuthRemoteDataSource? remote,
    DatabaseHelper? db,
    SyncService? sync,
  })  : _remote = remote ?? AuthRemoteDataSource(),
        _db = db ?? DatabaseHelper.instance,
        _sync = sync ?? SyncService.instance;

  final AuthRemoteDataSource _remote;
  final DatabaseHelper _db;
  final SyncService _sync;

  static const _maxAttempts = 5;
  static const _lockMinutes = 30;
  static const _attemptsKey = 'login_attempts';
  static const _lockKey = 'login_lock_until';

  AsesorModel? _asesor;
  AsesorModel? get currentAsesor => _asesor;

  Future<AuthRestoreResult> restoreSession() async {
    final asesor = await _remote.restoreSession();
    if (asesor == null) {
      return const AuthRestoreResult(status: AuthStatus.idle);
    }

    _asesor = asesor;
    _sync.startSyncTimer();
    return AuthRestoreResult(
      status: AuthStatus.authenticated,
      asesor: asesor,
    );
  }

  Future<AuthLoginResult> login(
    String code,
    String password,
    String selectedRole,
  ) async {
    if (await _isLocked()) {
      final mins = await _lockRemainingMinutes();
      return AuthLoginResult(
        status: AuthStatus.bloqueado,
        error: 'Acceso bloqueado. Reintente en $mins minutos.',
      );
    }

    try {
      final asesor = await _remote.login(code, password, selectedRole);
      _asesor = asesor;
      await _clearAttempts();
      _sync.startSyncTimer();
      return AuthLoginResult(status: AuthStatus.authenticated, asesor: asesor);
    } catch (e) {
      await _registerFailedAttempt();
      final locked = await _isLocked();
      return AuthLoginResult(
        status: locked ? AuthStatus.bloqueado : AuthStatus.error,
        error: NetworkHelper.friendlyMessage(e),
      );
    }
  }

  Future<int> pendingSyncCount() => _sync.getPendingSyncCount();

  Future<void> logout({bool force = false}) async {
    if (force) {
      await _db.clearTable('clientes');
      await _db.clearTable('solicitudes_borradores');
      await _db.clearTable('visitas_log');
      await _db.clearTable('acciones_cobranza');
      await _db.clearTable('prospectos');
    }
    _sync.stopSyncTimer();
    await _remote.logout();
    _asesor = null;
  }

  Future<bool> _isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_lockKey) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  Future<int> _lockRemainingMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_lockKey) ?? 0;
    final diff = until - DateTime.now().millisecondsSinceEpoch;
    return (diff / 60000).ceil().clamp(0, _lockMinutes);
  }

  Future<void> _registerFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
    await prefs.setInt(_attemptsKey, attempts);
    if (attempts >= _maxAttempts) {
      final until = DateTime.now()
          .add(const Duration(minutes: _lockMinutes))
          .millisecondsSinceEpoch;
      await prefs.setInt(_lockKey, until);
      await prefs.setInt(_attemptsKey, 0);
    }
  }

  Future<void> _clearAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lockKey);
  }
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.status,
    this.asesor,
    this.error,
  });

  final AuthStatus status;
  final AsesorModel? asesor;
  final String? error;

  bool get success => status == AuthStatus.authenticated;
}

class AuthRestoreResult {
  const AuthRestoreResult({
    required this.status,
    this.asesor,
  });

  final AuthStatus status;
  final AsesorModel? asesor;
}
