import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/network_monitor.dart';
import 'database_helper.dart';
import 'supabase_service.dart';

/// Sincronización en segundo plano (UML: SyncService).
class SyncService {
  SyncService._privateConstructor();
  static final SyncService instance = SyncService._privateConstructor();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final NetworkMonitor _network = NetworkMonitor.instance;

  Timer? _syncTimer;
  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySub;

  bool get isOnline => _network.isOnline;
  bool get isSyncing => _isSyncing;

  final StreamController<String> _syncStatusController =
      StreamController<String>.broadcast();
  Stream<String> get syncStatusStream => _syncStatusController.stream;

  Stream<bool> get connectivityStream => _network.onConnectivityChanged;

  Future<void> init() async {
    await _network.init();
    _connectivitySub ??= _network.onConnectivityChanged.listen((online) {
      if (online && !_isSyncing) {
        syncPendingData();
      }
    });
  }

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnectivityAndSync();
    });
    checkConnectivityAndSync();
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  Future<void> checkConnectivityAndSync() async {
    final online = await _network.checkNow();
    if (online && !_isSyncing) {
      await syncPendingData();
    }
  }

  Future<int> getPendingSyncCount() async {
    final visits = await _db.queryFiltered('visitas_log', 'synced = ?', [0]);
    final collections =
        await _db.queryFiltered('acciones_cobranza', 'synced = ?', [0]);
    final apps = await _db.queryFiltered(
      'solicitudes_borradores',
      'synced = ? AND estado != ?',
      [0, 'Borrador'],
    );
    final prospects = await _db.queryFiltered('prospectos', 'synced = ?', [0]);
    return visits.length +
        collections.length +
        apps.length +
        prospects.length;
  }

  Future<void> syncPendingData() async {
    if (!await _network.checkNow()) return;

    _isSyncing = true;
    _syncStatusController.add('Iniciando sincronizacion...');

    try {
      final pendingVisits =
          await _db.queryFiltered('visitas_log', 'synced = ?', [0]);
      if (pendingVisits.isNotEmpty) {
        _syncStatusController
            .add('Sincronizando ${pendingVisits.length} visitas...');
        for (final visit in pendingVisits) {
          final success = await _supabase.syncVisita(visit);
          if (success) {
            await _db.update('visitas_log', {'synced': 1}, 'id = ?', [
              visit['id'],
            ]);
          }
        }
      }

      final pendingCollections =
          await _db.queryFiltered('acciones_cobranza', 'synced = ?', [0]);
      if (pendingCollections.isNotEmpty) {
        _syncStatusController.add(
          'Sincronizando ${pendingCollections.length} cobranzas...',
        );
        for (final col in pendingCollections) {
          final success = await _supabase.syncAccionCobranza(col);
          if (success) {
            await _db.update('acciones_cobranza', {'synced': 1}, 'id = ?', [
              col['id'],
            ]);
          }
        }
      }

      final pendingProspects =
          await _db.queryFiltered('prospectos', 'synced = ?', [0]);
      if (pendingProspects.isNotEmpty) {
        _syncStatusController.add(
          'Sincronizando ${pendingProspects.length} prospectos...',
        );
        for (final p in pendingProspects) {
          final success = await _supabase.syncProspecto(p);
          if (success) {
            await _db.update('prospectos', {'synced': 1}, 'documento = ?', [
              p['documento'],
            ]);
          }
        }
      }

      final pendingApps = await _db.queryFiltered(
        'solicitudes_borradores',
        'synced = ? AND estado != ?',
        [0, 'Borrador'],
      );
      if (pendingApps.isNotEmpty) {
        _syncStatusController.add(
          'Transmitiendo ${pendingApps.length} solicitudes...',
        );
        for (final app in pendingApps) {
          final success = await _supabase.transmitSolicitud(app);
          if (success) {
            await _db.update('solicitudes_borradores', {'synced': 1}, 'id = ?', [
              app['id'],
            ]);
          }
        }
      }

      _syncStatusController.add('Sincronizacion completada.');
    } catch (e) {
      _syncStatusController.add('Error de sincronizacion: $e');
      debugPrint('Sync Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _syncStatusController.close();
  }
}
