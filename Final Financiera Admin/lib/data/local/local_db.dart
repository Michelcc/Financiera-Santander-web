import '../../services/database_helper.dart';

/// Abstracción LocalDb (UML) sobre SQLite.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> insert(String table, Map<String, dynamic> row) =>
      _db.insert(table, row);

  Future<List<Map<String, dynamic>>> queryAll(String table) =>
      _db.queryAll(table);

  Future<List<Map<String, dynamic>>> queryFiltered(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) =>
      _db.queryFiltered(table, where, whereArgs);

  Future<int> update(
    String table,
    Map<String, dynamic> row,
    String where,
    List<dynamic> whereArgs,
  ) =>
      _db.update(table, row, where, whereArgs);

  Future<int> delete(String table, String where, List<dynamic> whereArgs) =>
      _db.delete(table, where, whereArgs);

  Future<void> clearTable(String table) => _db.clearTable(table);
}
