import 'package:sqflite/sqflite.dart';
import '../models/medicine.dart';
import '../models/user.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }
  Future<void> deleteOldDB() async {
  String path = join(await getDatabasesPath(), 'medicine_reminder.db');
  await deleteDatabase(path);
}

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'medicine_reminder.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Users table with createdAt & updatedAt
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT UNIQUE,
            password TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');

        // Medicines table with scheduleDateTime stored as TEXT
        await db.execute('''
          CREATE TABLE medicines(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER,
            name TEXT,
            description TEXT,
            scheduleDateTime TEXT,
            dose TEXT,
            frequency TEXT,
            type TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');
      },
    );
  }

  // ------------------- Medicine -------------------

  Future<int> insertMedicine(Medicine med) async {
    final db = await database;
    return await db.insert('medicines', med.toMap());
  }

  Future<List<Medicine>> getUserMedicines(int userId) async {
    final db = await database;
    final maps = await db.query(
      'medicines',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'scheduleDateTime DESC',
    );
    return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
  }

  Future<int> deleteMedicine(int medId) async {
    final db = await database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [medId]);
  }

  Future<int> updateMedicine(Medicine med) async {
    final db = await database;
    return await db.update(
      'medicines',
      med.toMap(),
      where: 'id = ?',
      whereArgs: [med.id],
    );
  }

  // ------------------- User -------------------

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser(String email, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
}
