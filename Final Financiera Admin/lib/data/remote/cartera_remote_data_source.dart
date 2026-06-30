import '../../models/cartera_item.dart';
import '../../services/supabase_service.dart';

/// Cartera remota vía Supabase/FastAPI (UML: CarteraRemoteDataSource).
class CarteraRemoteDataSource {
  CarteraRemoteDataSource({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  String? get asesorId => _supabase.currentAsesorId;

  Future<bool> downloadDailyPortfolio() async {
    await _supabase.downloadDailyPortfolio();
    return true;
  }

  /// Descarga y devuelve filas ya normalizadas (sin depender solo de SQLite).
  Future<List<CarteraItem>> fetchPortfolioItems() async {
    final rows = await _supabase.fetchPortfolioRows();
    return rows.map(CarteraItem.fromMap).toList();
  }

  Future<bool> syncVisita(Map<String, dynamic> visit) =>
      _supabase.syncVisita(visit);
}
