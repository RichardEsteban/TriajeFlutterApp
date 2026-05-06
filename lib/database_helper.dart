import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'nutri_expert.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE children (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        birthDate TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        childId TEXT NOT NULL,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        nutritionalStatus TEXT NOT NULL,
        statusColor INTEGER NOT NULL,
        recommendations TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (childId) REFERENCES children (id)
      )
    ''');
  }

  // Métodos para Children
  Future<int> insertChild(Map<String, dynamic> child) async {
    Database db = await database;
    return await db.insert('children', child);
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    Database db = await database;
    return await db.query('children');
  }

  Future<List<Map<String, dynamic>>> searchChildren(String query) async {
    Database db = await database;
    return await db.query('children', where: 'name LIKE ?', whereArgs: ['%$query%']);
  }

  Future<int> updateChild(String id, Map<String, dynamic> child) async {
    Database db = await database;
    return await db.update('children', child, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteChild(String id) async {
    Database db = await database;
    await db.delete('measurements', where: 'childId = ?', whereArgs: [id]);
    return await db.delete('children', where: 'id = ?', whereArgs: [id]);
  }

  // Métodos para Measurements
  Future<int> insertMeasurement(Map<String, dynamic> measurement) async {
    Database db = await database;
    return await db.insert('measurements', measurement);
  }

  Future<List<Map<String, dynamic>>> getMeasurementsForChild(String childId) async {
    Database db = await database;
    return await db.query('measurements', where: 'childId = ?', whereArgs: [childId], orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getRecentMeasurements(String childId, int months) async {
    Database db = await database;
    DateTime cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return await db.query('measurements',
      where: 'childId = ? AND date >= ?',
      whereArgs: [childId, cutoff.toIso8601String()],
      orderBy: 'date ASC'
    );
  }

  Future<int> deleteMeasurement(String id) async {
    Database db = await database;
    return await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }
}