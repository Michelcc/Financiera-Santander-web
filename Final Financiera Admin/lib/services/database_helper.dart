import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static sql.Database? _database;
  static bool _useMockDb = false;
  static final Map<String, List<Map<String, dynamic>>> _mockTables = {};

  Future<sql.Database?> get database async {
    if (kIsWeb || (!defaultTargetPlatform.name.contains('android') && !defaultTargetPlatform.name.contains('ios'))) {
      _useMockDb = true;
      return null;
    }
    if (_database != null) return _database;
    try {
      _database = await _initDatabase();
      return _database;
    } catch (e) {
      debugPrint('Error inicializando SQLite, activando mock database: $e');
      _useMockDb = true;
      return null;
    }
  }

  Future<sql.Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'santander_campo.db');
    return await sql.openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sql.Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id TEXT PRIMARY KEY,
        documento TEXT,
        nombre TEXT,
        telefono TEXT,
        negocio_nombre TEXT,
        negocio_tipo TEXT,
        direccion TEXT,
        latitud REAL,
        longitud REAL,
        tipo_gestion TEXT,
        prioridad INTEGER,
        score_transaccional INTEGER,
        score_campo INTEGER DEFAULT 0,
        score_final INTEGER DEFAULT 0,
        hipotesis_credito REAL DEFAULT 0,
        segmento TEXT DEFAULT 'ESTANDAR',
        deuda_total REAL,
        mora_dias INTEGER,
        ultimo_pago_fecha TEXT,
        monto_preaprobado REAL,
        plazo_preaprobado INTEGER,
        tasa_preaprobada REAL,
        historial_pagos TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE solicitudes_borradores (
        id TEXT PRIMARY KEY,
        cliente_id TEXT,
        datos_personales TEXT,
        datos_negocio TEXT,
        condiciones TEXT,
        firma_path TEXT,
        nitidez_ok INTEGER,
        fotos_paths TEXT,
        score_campo INTEGER,
        score_final INTEGER,
        segmento TEXT,
        monto_aprobado REAL,
        plazo_aprobado INTEGER,
        cuota_mensual REAL,
        estado TEXT,
        notas_internas TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE visitas_log (
        id TEXT PRIMARY KEY,
        cliente_id TEXT,
        resultado TEXT,
        observacion TEXT,
        latitud REAL,
        longitud REAL,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE acciones_cobranza (
        id TEXT PRIMARY KEY,
        cliente_id TEXT,
        tipo TEXT,
        observacion TEXT,
        compromiso_fecha TEXT,
        compromiso_monto REAL,
        latitud REAL,
        longitud REAL,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE prospectos (
        documento TEXT PRIMARY KEY,
        nombre TEXT,
        telefono TEXT,
        negocio_nombre TEXT,
        ingresos REAL,
        pre_evaluacion TEXT,
        motivo_desercion TEXT,
        latitud REAL,
        longitud REAL,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(sql.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE clientes ADD COLUMN score_campo INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE clientes ADD COLUMN score_final INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE clientes ADD COLUMN hipotesis_credito REAL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE clientes ADD COLUMN segmento TEXT DEFAULT 'ESTANDAR'",
      );
    }
  }

  // Helper CRUD methods supporting fallback mock database
  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    if (_useMockDb) {
      _mockTables.putIfAbsent(table, () => []);
      // Remove existing if has same primary key (if applicable)
      final primaryKeyField = _getPrimaryKeyField(table);
      if (primaryKeyField != null && row.containsKey(primaryKeyField)) {
        _mockTables[table]!.removeWhere((item) => item[primaryKeyField] == row[primaryKeyField]);
      }
      _mockTables[table]!.add(row);
      await _saveMockDataToPrefs(table);
      return 1;
    }
    return await db!.insert(table, row, conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    if (_useMockDb) {
      await _loadMockDataFromPrefs(table);
      return _mockTables[table] ?? [];
    }
    return await db!.query(table);
  }

  Future<List<Map<String, dynamic>>> queryFiltered(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    if (_useMockDb) {
      await _loadMockDataFromPrefs(table);
      final list = _mockTables[table] ?? [];
      // Simple filter mock
      if (where.contains('cliente_id = ?')) {
        final arg = whereArgs.first.toString();
        return list.where((item) => item['cliente_id'] == arg).toList();
      }
      if (where.contains('id = ?')) {
        final arg = whereArgs.first.toString();
        return list.where((item) => item['id'] == arg).toList();
      }
      if (where.contains('documento = ?')) {
        final arg = whereArgs.first.toString();
        return list.where((item) => item['documento'] == arg).toList();
      }
      return list;
    }
    return await db!.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> row, String where, List<dynamic> whereArgs) async {
    final db = await database;
    if (_useMockDb) {
      _mockTables.putIfAbsent(table, () => []);
      final list = _mockTables[table]!;
      int updatedCount = 0;

      // Simple implementation
      final key = where.split(' ').first;
      final val = whereArgs.first;

      for (int i = 0; i < list.length; i++) {
        if (list[i][key] == val) {
          list[i] = {...list[i], ...row};
          updatedCount++;
        }
      }
      await _saveMockDataToPrefs(table);
      return updatedCount;
    }
    return await db!.update(table, row, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    if (_useMockDb) {
      _mockTables.putIfAbsent(table, () => []);
      final list = _mockTables[table]!;
      final key = where.split(' ').first;
      final val = whereArgs.first;
      final initialLen = list.length;
      list.removeWhere((item) => item[key] == val);
      await _saveMockDataToPrefs(table);
      return initialLen - list.length;
    }
    return await db!.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> clearTable(String table) async {
    final db = await database;
    if (_useMockDb) {
      _mockTables[table] = [];
      await _saveMockDataToPrefs(table);
      return;
    }
    await db!.delete(table);
  }

  String? _getPrimaryKeyField(String table) {
    if (table == 'clientes' || table == 'solicitudes_borradores' || table == 'visitas_log' || table == 'acciones_cobranza') {
      return 'id';
    }
    if (table == 'prospectos') {
      return 'documento';
    }
    return null;
  }

  Future<void> _saveMockDataToPrefs(String table) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _mockTables[table] ?? [];
      await prefs.setString('mock_db_$table', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadMockDataFromPrefs(String table) async {
    try {
      if (_mockTables.containsKey(table) && _mockTables[table]!.isNotEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('mock_db_$table');
      if (str != null) {
        final decoded = jsonDecode(str) as List<dynamic>;
        _mockTables[table] = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
  }
}
