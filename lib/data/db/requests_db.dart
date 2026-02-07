import 'package:exodus/data/model/request.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class RequestDb {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'requests.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE requests (
            id TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            language TEXT,
            comment TEXT,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE requests ADD COLUMN language TEXT');
        }
      },
    );
  }

  // CREATE
  Future<void> insert(Request request) async {
    final db = await database;
    await db.insert(
      'requests',
      request.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // READ
  Future<List<Request>> getAll() async {
    final db = await database;
    final data = await db.query('requests', orderBy: 'createdAt DESC');

    return data.map((e) => Request.fromMap(e)).toList();
  }

  Future<List<Request>> getBetween(DateTime start, DateTime end) async {
    final db = await database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final data = await db.query(
      'requests',
      where: 'createdAt >= ? AND createdAt < ?',
      whereArgs: [startMs, endMs],
      orderBy: 'createdAt DESC',
    );
    return data.map((e) => Request.fromMap(e)).toList();
  }

  Future<List<Request>> getByDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return getBetween(start, end);
  }

  // UPDATE
  Future<void> update(Request request) async {
    final db = await database;
    await db.update(
      'requests',
      request.toMap(),
      where: 'id = ?',
      whereArgs: [request.id],
    );
  }

  // DELETE
  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('requests', where: 'id = ?', whereArgs: [id]);
  }
}
