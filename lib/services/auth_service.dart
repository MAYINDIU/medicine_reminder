import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _db = DatabaseService();

  // ✅ Signup
  Future<bool> signup(String name, String email, String password) async {
    final exists = await _db.getUserByEmail(email);
    if (exists != null) return false;

    final user = User(
      name: name,
      email: email,
      password: password,
      createdAt: DateTime.now(), // ✅ DateTime type
    );

    await _db.insertUser(user);
    return true;
  }

  // ✅ Login
  Future<User?> login(String email, String password) async {
    final user = await _db.getUserByEmail(email);
    if (user != null && user.password == password) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('userId', user.id!);
      prefs.setString('userName', user.name);
      prefs.setString('userEmail', user.email);
      return user;
    }
    return null;
  }

  // ✅ Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ✅ Get current user ID
  Future<int?> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }
}
