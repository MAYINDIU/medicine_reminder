import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⬅️ NEW IMPORT
import '../models/user.dart';
import '../services/db_helper.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _db = DBHelper();

  final Color _primaryAppColor = Colors.teal.shade600;
  final Color _accentColor = Colors.indigo.shade400;

  @override
  void initState() {
    super.initState();
    // 🚀 Check for stored session immediately when the widget is created
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ######################################################################
  // ✅ NEW AUTO-LOGIN LOGIC
  // ######################################################################
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming you store the User's ID in shared preferences
    final int? userId = prefs.getInt('currentUserId');

    if (userId != null) {
      // User ID found, attempt to fetch the full User object from DB
      // NOTE: Your DBHelper needs a method like getUserById
      User? user = await _db.getUserById(userId); 

      if (user != null) {
        // Session is valid and user object retrieved
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(user: user)),
          );
        }
      } else {
        // Stored ID is invalid (e.g., user deleted in DB), clear the storage
        await prefs.remove('currentUserId');
      }
    }
  }

  // ######################################################################
  // ✅ UPDATED LOGIN METHOD
  // ######################################################################
  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Show loading indicator
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 15),
            Text("Logging in...", style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: _accentColor,
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Attempt to retrieve user
    User? user = await _db.getUser(email, password);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (user != null) {
      // 🔑 Success: Store User ID in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentUserId', user.id!); // Assuming 'id' is non-null after successful retrieval

      // Navigate to the home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(user: user)),
      );
    } else {
      // Failure: Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login failed. Invalid email or password."),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The build method remains the same, showing the login form
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Application Logo/Title
                Icon(
                  Icons.local_hospital_outlined,
                  size: 100,
                  color: _primaryAppColor,
                ),
                SizedBox(height: 10),
                Text(
                  "Medicine Reminder",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _primaryAppColor,
                  ),
                ),
                Text(
                  "Welcome back! Login to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 40),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    hintText: "example@email.com",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_outlined, color: _accentColor),
                    floatingLabelStyle: TextStyle(color: _primaryAppColor, fontWeight: FontWeight.bold),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "Enter your secure password",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_outline, color: _accentColor),
                    floatingLabelStyle: TextStyle(color: _primaryAppColor, fontWeight: FontWeight.bold),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 30),

                // Login Button
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 55),
                    backgroundColor: _primaryAppColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    "LOGIN",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 20),

                // Register Button
                TextButton(
                  onPressed: _navigateToRegister,
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                      children: [
                        TextSpan(
                          text: "Register Now",
                          style: TextStyle(
                            color: _accentColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}