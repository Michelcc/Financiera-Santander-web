import '../../models/cartera_item.dart';
import 'local_db.dart';

/// Cache local de cartera (UML: CarteraLocalDataSource).
class CarteraLocalDataSource {
  CarteraLocalDataSource({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<void> guardarCache(List<CarteraItem> items) async {
    await _db.clearTable('clientes');
    for (final item in items) {
      await _db.insert('clientes', item.toMap());
    }
  }

  Future<List<CarteraItem>> obtenerCache() async {
    final rows = await _db.queryAll('clientes');
    final items = rows.map(CarteraItem.fromMap).toList();
    items.sort((a, b) {
      if (a.prioridad != b.prioridad) {
        return a.prioridad.compareTo(b.prioridad);
      }
      return a.nombre.compareTo(b.nombre);
    });
    return items;
  }

  Future<List<Map<String, dynamic>>> visitasPendientes() =>
      _db.queryFiltered('visitas_log', 'synced = ?', [0]);

  Future<Map<String, String>> visitasHoy() async {
    final visitsList = await _db.queryAll('visitas_log');
    final map = <String, String>{};
    for (final v in visitsList) {
      map[v['cliente_id'] ?? ''] = v['resultado'] ?? 'Visitado';
    }
    return map;
  }

  Future<void> marcarVisitaLocal(Map<String, dynamic> visitData) async {
    await _db.insert('visitas_log', visitData);
  }

  Future<void> marcarVisitaSincronizada(String visitId) async {
    await _db.update('visitas_log', {'synced': 1}, 'id = ?', [visitId]);
  }

  Future<void> actualizarCoordenadas(
    String clientId,
    double lat,
    double lng,
  ) async {
    await _db.update(
      'clientes',
      {'latitud': lat, 'longitud': lng},
      'id = ?',
      [clientId],
    );
  }
}
