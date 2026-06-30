import '../../core/network/network_monitor.dart';
import '../../data/local/cartera_local_data_source.dart';
import '../../data/remote/cartera_remote_data_source.dart';
import '../../models/cartera_item.dart';
import '../../services/sync_service.dart';

/// Resultado offline-first de carga de cartera.
class CarteraLoadResult {
  const CarteraLoadResult({
    required this.items,
    required this.visitasHoy,
    required this.fromCache,
    required this.isOffline,
    this.error,
  });

  final List<CarteraItem> items;
  final Map<String, String> visitasHoy;
  final bool fromCache;
  final bool isOffline;
  final String? error;
}

/// Orquestador cartera (UML: CarteraRepository).
class CarteraRepository {
  CarteraRepository({
    CarteraLocalDataSource? local,
    CarteraRemoteDataSource? remote,
    NetworkMonitor? network,
    SyncService? sync,
  })  : _local = local ?? CarteraLocalDataSource(),
        _remote = remote ?? CarteraRemoteDataSource(),
        _network = network ?? NetworkMonitor.instance,
        _sync = sync ?? SyncService.instance;

  final CarteraLocalDataSource _local;
  final CarteraRemoteDataSource _remote;
  final NetworkMonitor _network;
  final SyncService _sync;

  Future<CarteraLoadResult> obtenerCartera({String? asesorId}) async {
    final online = await _network.checkNow();

    if (online) {
      await sincronizarPendientes();
      try {
        final items = await _remote.fetchPortfolioItems();
        if (items.isEmpty) {
          final cached = await _local.obtenerCache();
          if (cached.isEmpty) {
            throw Exception(
              'No hay clientes en Supabase. Ejecute supabase_admin_cartera_final.sql '
              'en el SQL Editor de Supabase y vuelva a sincronizar.',
            );
          }
          final visitas = await _local.visitasHoy();
          return CarteraLoadResult(
            items: cached,
            visitasHoy: visitas,
            fromCache: true,
            isOffline: false,
            error: 'Servidor devolvió 0 clientes — mostrando caché (${cached.length})',
          );
        }
        await _local.guardarCache(items);
        final visitas = await _local.visitasHoy();
        return CarteraLoadResult(
          items: items,
          visitasHoy: visitas,
          fromCache: false,
          isOffline: false,
        );
      } catch (e) {
        final items = await _local.obtenerCache();
        final visitas = await _local.visitasHoy();
        return CarteraLoadResult(
          items: items,
          visitasHoy: visitas,
          fromCache: true,
          isOffline: false,
          error: e.toString(),
        );
      }
    }

    final items = await _local.obtenerCache();
    final visitas = await _local.visitasHoy();
    return CarteraLoadResult(
      items: items,
      visitasHoy: visitas,
      fromCache: true,
      isOffline: true,
    );
  }

  Future<CarteraLoadResult> syncFromServer() async {
    final online = await _network.checkNow();
    if (!online) {
      return obtenerCartera();
    }
    try {
      final items = await _remote.fetchPortfolioItems();
      if (items.isEmpty) {
        throw Exception(
          'Supabase devolvió 0 clientes. Ejecute supabase_admin_cartera_final.sql '
          'en Supabase → SQL Editor, luego cierre sesión y entre con OP001.',
        );
      }
      await _local.guardarCache(items);
      final visitas = await _local.visitasHoy();
      return CarteraLoadResult(
        items: items,
        visitasHoy: visitas,
        fromCache: false,
        isOffline: false,
      );
    } catch (e) {
      final items = await _local.obtenerCache();
      return CarteraLoadResult(
        items: items,
        visitasHoy: await _local.visitasHoy(),
        fromCache: true,
        isOffline: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sincronizarPendientes() => _sync.syncPendingData();

  Future<void> marcarVisita({
    required Map<String, dynamic> visitData,
  }) async {
    await _local.marcarVisitaLocal(visitData);

    final online = await _network.checkNow();
    if (online) {
      final ok = await _remote.syncVisita(visitData);
      if (ok) {
        await _local.marcarVisitaSincronizada(visitData['id'] as String);
      }
    } else {
      _sync.checkConnectivityAndSync();
    }
  }

  Future<void> actualizarCoordenadas(
    String clientId,
    double lat,
    double lng,
  ) =>
      _local.actualizarCoordenadas(clientId, lat, lng);

  Future<List<CarteraItem>> leerCacheLocal() => _local.obtenerCache();
}
