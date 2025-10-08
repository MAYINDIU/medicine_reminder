import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/medicine.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_medicine.db');
    return await openDatabase(path, version: 1, onCreate: _create);
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        dosage TEXT,
        time TEXT,
        repeat TEXT,
        note TEXT,
        active INTEGER DEFAULT 1
      )
    ''');
  }

  // User CRUD
  Future<int> insertUser(User u) async => await (await db).insert('users', u.toMap());
  Future<User?> getUserByEmail(String email) async {
    final res = await (await db).query('users', where: 'email = ?', whereArgs: [email]);
    return res.isNotEmpty ? User.fromMap(res.first) : null;
  }

  // Medicine CRUD
  Future<int> insertMedicine(Medicine m) async => await (await db).insert('medicines', m.toMap());
  Future<List<Medicine>> getMedicinesByUser(int userId) async {
    final res = await (await db).query('medicines', where: 'user_id = ?', whereArgs: [userId], orderBy: 'time ASC');
    return res.map((e) => Medicine.fromMap(e)).toList();
  }
  Future<void> updateMedicine(Medicine m) async => await (await db).update('medicines', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  Future<void> deleteMedicine(int id) async => await (await db).delete('medicines', where: 'id = ?', whereArgs: [id]);
}
