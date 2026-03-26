import '../app_database.dart';
import '../models/user_model.dart';

class UserLocalDataSource {
  UserLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<UserModel?> getActiveUser() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.usersTable,
      where: 'is_active = ?',
      whereArgs: const [1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.usersTable,
      where: 'LOWER(email) = LOWER(?)',
      whereArgs: [email],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserByFirebaseUid(String firebaseUid) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.usersTable,
      where: 'firebase_uid = ?',
      whereArgs: [firebaseUid],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.usersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await _appDatabase.database;
    final maps = await db.query(AppDatabase.usersTable, orderBy: 'id ASC');
    return maps.map(UserModel.fromMap).toList();
  }

  Future<int> insertUser(UserModel user) async {
    final db = await _appDatabase.database;
    return db.insert(AppDatabase.usersTable, user.toMap());
  }

  Future<int> updateUser(UserModel user) async {
    final db = await _appDatabase.database;
    return db.update(
      AppDatabase.usersTable,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUserById(int userId) async {
    final db = await _appDatabase.database;
    return db.delete(
      AppDatabase.usersTable,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> setOnlyActiveUser(int userId) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(AppDatabase.usersTable, {
        'is_active': 0,
        'updated_at': nowIso,
      });
      await txn.update(
        AppDatabase.usersTable,
        {'is_active': 1, 'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  Future<void> deactivateAllUsers() async {
    final db = await _appDatabase.database;
    await db.update(AppDatabase.usersTable, {
      'is_active': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
